# Vahana Anveshana

Buying, owning and selling cars, for Linux, Windows 11 and Android. Part of **Brahma**, a suite of
life-management apps that share one encrypted account. Its sibling for homes is
[Graha Anveshana](https://github.com/sudharamachandranrajeev/graha-anveshana). The shared core lives
in [brahma](https://github.com/sudharamachandranrajeev/brahma).

Status: first release, for testing. Built with Flutter 3.47.7; local data in an encrypted SQLite
database (SQLite3MultipleCiphers); optional sync through your own PocketBase server with end-to-end
encryption.

## What it does

- **Search.** Search links for AutoTrader, Gumtree, Facebook Marketplace, eBay, UsedCarsNI, DoneDeal,
  PistonHeads, online stores, dealer groups and new-car deal sites, filled in from your make, model,
  budget and postcode (Northern Ireland sites first for BT postcodes), plus your own sites. Pages
  open in your browser; only adverts you paste are read.
- **Garage.** Cars you found, from an advert link or typed in, by stage. Each car's page has:
  - *Buying:* price against similar cars you saved, red flags (too cheap, odd mileage, used EV),
    asking-price history, free GOV.UK checks, and checklists for before paying and collection day.
  - *Owning:* MOT, tax, insurance and service dates counting down (first MOT 3 years on, 4 in
    Northern Ireland), calendar reminders, a logbook with real economy and cost a mile, PCP mileage
    pace, and dealer-rights dates.
  - *Selling:* offers side by side, a safe-selling list, the DVLA steps, a service history to paste
    into an advert, and the true cost of owning once sold.
- **Finance.** Cash, loan, HP, PCP and lease compared by real cost, and running costs.
- **Guide.** Rights, tax, the motor finance redress scheme and the checks before you pay.

Figures are as of October 2026 and are a starting point for your own checks, not advice.

## Install a test build

Builds are on the releases page, each with `SHA256SUMS.txt`.

- **Linux (x86-64):** unpack `Vahana-<version>-linux-x64.tar.gz` and run `./install.sh` (for your user
  only; `./install.sh --uninstall` removes it). Needs GTK 3, libsecret and a running keyring.
- **Windows 10/11:** run the `-windows-x64-setup.exe` (no admin rights), or unzip the portable build.
  SmartScreen warns because the build is not code-signed: *More info > Run anyway*.
- **Android 7+:** install the `.apk`.

## Develop

```sh
flutter pub get
flutter run -d linux
```

`brahma_core` comes from the brahma repository. To work on both at once, add a
`pubspec_overrides.yaml` (ignored by git):

```yaml
dependency_overrides:
  brahma_core:
    path: ../brahma/core
```

Tests: `flutter test`. Regenerate the database code with `dart run build_runner build`.
