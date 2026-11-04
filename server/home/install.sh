#!/usr/bin/env bash
# Brahma home sync server: installs, looks after and removes the server on a
# Linux computer that stays on at home. Run it from a copy of the Brahma
# repository (brahma/server/home/install.sh), as your normal user, not root.
#
#   ./install.sh                 install or repair, then print the setup link
#   ./install.sh --port 8091     use another port (default 8090)
#   ./install.sh --update        after `git pull`: copy the new code, restart
#   ./install.sh --status        is it running, accounts, last backup, check
#   ./install.sh --link          the server's addresses and setup link (+ QR)
#   ./install.sh --backup        back up now (a daily backup runs by itself)
#   ./install.sh --restore FILE  put a backup back
#   ./install.sh --uninstall     stop and remove the server (asks about data)
#   ./install.sh --yes           answer yes to every question (for scripts)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
code="${XDG_DATA_HOME:-$HOME/.local/share}/brahma-server/app"
data="${BRAHMA_SERVER_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/brahma-server}"
units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
service=brahma-server
port=""
yes=false
action=install
restore_file=""

bold=$'\e[1m' dim=$'\e[2m' green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' off=$'\e[0m'
[[ -t 1 ]] || { bold="" dim="" green="" yellow="" red="" off=""; }
say() { printf '%s\n' "$*"; }
step() { printf '\n%s==> %s%s\n' "$bold" "$*" "$off"; }
ok() { printf '  %s✓%s %s\n' "$green" "$off" "$*"; }
hint() { printf '  %s→%s %s\n' "$yellow" "$off" "$*"; }
die() { printf '%sProblem:%s %s\n' "$red" "$off" "$*" >&2; exit 1; }
ask() {
  $yes && return 0
  [[ -t 0 ]] || return 1
  local reply
  read -r -p "  $1 [y/N] " reply
  [[ $reply =~ ^[Yy] ]]
}

while (($#)); do
  case "$1" in
    --port) port="${2:?--port needs a number}"; shift ;;
    --update) action=update ;;
    --status) action=status ;;
    --link) action=link ;;
    --backup) action=backup ;;
    --restore) action=restore; restore_file="${2:?--restore needs a backup file}"; shift ;;
    --uninstall) action=uninstall ;;
    --yes | -y) yes=true ;;
    -h | --help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option $1 (try --help)" ;;
  esac
  shift
done
[[ -z $port || $port =~ ^[0-9]+$ && $port -ge 1024 && $port -le 65535 ]] || die "Pick a port between 1024 and 65535."

home_cmd() { BRAHMA_SERVER_HOME="$data" node "$code/src/home.ts" "$@"; }

check_basics() {
  [[ $(id -u) -ne 0 ]] || die "Run this as your normal user, not with sudo. It asks for sudo itself when needed."
  [[ $(uname -s) == Linux ]] || die "The home server installer needs Linux. On other computers, use the cloud server instead."
  command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1 ||
    die "This computer has no systemd user session, which keeps the server running. Use a Linux with systemd (Ubuntu, Fedora, Arch, Debian...)."
  local major=0
  command -v node >/dev/null && major="$(node -p 'process.versions.node.split(".")[0]')"
  if ((major < 24)); then
    say "${red}Node.js 24 or newer is needed${off} (found: $(command -v node >/dev/null && node --version || echo none))."
    if command -v pacman >/dev/null; then hint "Install it with: sudo pacman -S nodejs"
    elif command -v dnf >/dev/null; then hint "Install it with: sudo dnf install nodejs  (Fedora 42+ has 24 or newer)"
    elif command -v apt-get >/dev/null; then hint "Ubuntu and Debian ship an older Node. Get 24+ from https://nodejs.org (\"Linux\" download) or https://github.com/nodesource/distributions"
    else hint "Get it from https://nodejs.org"
    fi
    exit 1
  fi
  ok "Node.js $(node --version)"
  command -v curl >/dev/null || die "curl is needed to check the server. Install it with your package manager (for example: sudo apt install curl)."
}

copy_code() {
  [[ -f $here/src/home.ts && -f $here/schema.sql ]] || die "Run this from the Brahma repository: brahma/server/home/install.sh"
  umask 077
  mkdir -p "$code"
  rm -rf "$code.new"
  mkdir -p "$code.new/src"
  cp "$here"/src/{app.ts,home.ts,sqlite.ts} "$code.new/src/"
  cp "$here/schema.sql" "$code.new/"
  rm -rf "$code" && mv "$code.new" "$code"
  ok "Server program copied to $code"
}

# systemd reads % as a specifier; double it in paths that go into units.
unit_path() { printf '%s' "${1//%/%%}"; }

write_units() {
  local node env_line
  node="$(unit_path "$(command -v node)")"
  env_line="Environment=\"BRAHMA_SERVER_HOME=$(unit_path "$data")\""
  mkdir -p "$units"
  cat >"$units/$service.service" <<EOF
[Unit]
Description=Brahma sync server

[Service]
$env_line
ExecStart="$node" "$(unit_path "$code")/src/home.ts" serve
Restart=always
RestartSec=5
UMask=0077
NoNewPrivileges=yes

[Install]
WantedBy=default.target
EOF
  cat >"$units/$service-backup.service" <<EOF
[Unit]
Description=Back up the Brahma sync server

[Service]
Type=oneshot
$env_line
ExecStart="$node" "$(unit_path "$code")/src/home.ts" backup
EOF
  cat >"$units/$service-backup.timer" <<EOF
[Unit]
Description=Daily backup of the Brahma sync server

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=15m

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  ok "Service and daily backup installed"
}

configured_port() { sed -n 's/^PORT=//p' "$data/server.env" 2>/dev/null || true; }

port_busy() {
  local p="$1"
  systemctl --user is-active --quiet "$service" && return 1
  (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null
}

wait_healthy() {
  local p
  p="$(configured_port)"
  for _ in $(seq 1 40); do
    curl -fsS -m 2 "http://127.0.0.1:$p/api/health" >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  return 1
}

keep_running() {
  step "Keeping it running when you are logged out"
  if [[ $(loginctl show-user "$USER" -p Linger --value 2>/dev/null) == yes ]]; then
    ok "Starts when the computer starts, even before anyone logs in"
  else
    say "  Without this, the server stops when you log out and waits for you to log in after a restart."
    if ask "Let it start with the computer? (runs: sudo loginctl enable-linger $USER)"; then
      sudo loginctl enable-linger "$USER" && ok "Starts with the computer"
    else
      hint "Later: sudo loginctl enable-linger $USER"
    fi
  fi
}

open_firewall() {
  local p
  p="$(configured_port)"
  step "Letting your other devices reach it"
  if command -v ufw >/dev/null && systemctl is-active --quiet ufw; then
    if sudo -n ufw status 2>/dev/null | grep -qw "$p/tcp"; then
      ok "Firewall (ufw) already lets devices in on port $p"
      return
    fi
    say "  The firewall (ufw) blocks other devices until you allow them."
    if ask "Allow devices on your home network and Tailscale to reach port $p?"; then
      sudo ufw allow from 10.0.0.0/8 to any port "$p" proto tcp comment 'Brahma sync' >/dev/null
      sudo ufw allow from 172.16.0.0/12 to any port "$p" proto tcp comment 'Brahma sync' >/dev/null
      sudo ufw allow from 192.168.0.0/16 to any port "$p" proto tcp comment 'Brahma sync' >/dev/null
      sudo ufw allow in on tailscale0 to any port "$p" proto tcp comment 'Brahma sync' >/dev/null
      ok "Home network and Tailscale allowed on port $p (the internet is not)"
    else
      hint "Later: sudo ufw allow from 192.168.0.0/16 to any port $p proto tcp"
    fi
  elif command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; then
    if ask "Open port $p in firewalld for your home network?"; then
      sudo firewall-cmd --permanent --zone=home --add-port="$p/tcp" >/dev/null && sudo firewall-cmd --reload >/dev/null
      ok "Port $p open in the firewalld home zone"
      hint "Check your Wi-Fi connection is in the 'home' zone: firewall-cmd --get-active-zones"
    fi
  else
    ok "No active firewall found"
  fi
}

advice() {
  step "Tips"
  if command -v tailscale >/dev/null && tailscale ip -4 >/dev/null 2>&1; then
    ok "Tailscale is on: your devices can sync away from home too, when Tailscale is on there"
  else
    hint "To sync away from home, install Tailscale (free, https://tailscale.com/download) here and on each phone or computer, then run ./install.sh --link again."
  fi
  if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    hint "This is a laptop: keep it plugged in, and set it to never sleep and to stay on with the lid closed (Settings, Power)."
  fi
  hint "Give this computer a fixed address in your router's settings (often called 'DHCP reservation'), so the address in your apps keeps working."
}

show_link() {
  step "Connect your apps"
  local out
  out="$(home_cmd link)"
  grep -v '^SETUP-LINK ' <<<"$out" | sed 's/^/  /'
  local link
  link="$(sed -n 's/^SETUP-LINK //p' <<<"$out")"
  if [[ -n $link ]]; then
    say ""
    say "  ${bold}Setup link${off} (paste it in any Brahma app, or scan the code below):"
    say "  $link"
    if command -v qrencode >/dev/null; then
      qrencode -t ANSIUTF8 -m 2 "$link"
    else
      hint "Install qrencode to show this as a QR code you can scan with your phone."
    fi
    say ""
    say "  In the app: ${bold}Sync across my devices${off} → ${bold}I have a server${off} → paste the link → create your account."
    say "  ${dim}The link holds a one-time setup code. Don't share it; it stops working once your account exists.${off}"
  fi
}

install() {
  step "Checking this computer"
  check_basics
  step "Installing the Brahma sync server"
  copy_code
  local want="${port:-$(configured_port)}"
  want="${want:-8090}"
  if port_busy "$want"; then
    die "Something else already uses port $want. Stop it, or pick another port: ./install.sh --port 8091"
  fi
  home_cmd init "$want" | sed 's/^/  /'
  write_units
  systemctl --user enable --now "$service.service" "$service-backup.timer" >/dev/null 2>&1
  systemctl --user restart "$service.service"
  wait_healthy || die "The server did not start. See: journalctl --user -u $service -n 50"
  ok "Running on port $(configured_port)"
  keep_running
  open_firewall
  advice
  show_link
}

case "$action" in
  install) install ;;
  update)
    check_basics
    copy_code
    systemctl --user restart "$service.service"
    wait_healthy && ok "Updated and running" || die "Updated, but it did not start: journalctl --user -u $service -n 50"
    ;;
  status)
    if systemctl --user is-active --quiet "$service"; then ok "Running"; else say "${red}Not running${off} (start it: systemctl --user start $service)"; fi
    home_cmd status | sed 's/^/  /'
    systemctl --user list-timers "$service-backup.timer" --no-pager 2>/dev/null | sed -n 2p | awk '{print "  Next backup: "$1" "$2" "$3}'
    ;;
  link) show_link ;;
  backup) home_cmd backup | sed 's/^/  /' ;;
  restore)
    [[ -f $restore_file ]] || die "No such file: $restore_file"
    ask "Replace the server's data with $restore_file? (the current data is kept in backups/)" || exit 1
    systemctl --user stop "$service.service"
    # Start it again whatever happens, so a bad file never leaves sync down.
    trap 'systemctl --user start "$service.service"' EXIT
    home_cmd restore "$restore_file" | sed 's/^/  /'
    trap - EXIT
    systemctl --user start "$service.service"
    wait_healthy && ok "Restored and running" || die "Restored, but it did not start: journalctl --user -u $service -n 50"
    ;;
  uninstall)
    ask "Stop and remove the Brahma sync server from this computer?" || exit 1
    systemctl --user disable --now "$service.service" "$service-backup.timer" >/dev/null 2>&1 || true
    rm -f "$units/$service.service" "$units/$service-backup.service" "$units/$service-backup.timer"
    systemctl --user daemon-reload
    rm -rf "$code"
    ok "Server removed"
    if [[ -d $data ]] && ! $yes && ask "Also delete its data and backups in $data? Your apps keep their own copy, but synced accounts on this server are gone for good."; then
      rm -rf "$data"
      ok "Data deleted"
    else
      hint "Data kept in $data"
    fi
    ;;
esac
