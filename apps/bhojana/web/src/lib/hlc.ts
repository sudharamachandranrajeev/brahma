// Hybrid logical clock (Kulkarni et al.), as brahma_core's hlc.dart. Every
// synced row carries the HLC of its last write; merges keep the row with the
// greater HLC. Stamps are fixed width so plain string comparison orders them,
// and the device id at the end breaks ties, so every device resolves the same
// conflict the same way.
export class HlcClock {
  /// Stamp for rows that ship with the app. Lower than any real write.
  static readonly seed = "000000000000000-000000-seed";

  readonly node: string;
  private readonly now: () => number;
  private millis = 0;
  private counter = 0;

  constructor(node: string, now: () => number = Date.now) {
    if (node.includes("-")) throw new Error('node must not contain "-"');
    this.node = node;
    this.now = now;
  }

  /// A new stamp for a local write; strictly greater than any stamp seen.
  tick(): string {
    const wall = this.now();
    if (wall > this.millis) {
      this.millis = wall;
      this.counter = 0;
    } else {
      this.counter++;
    }
    return format(this.millis, this.counter, this.node);
  }

  /// Folds a stamp from another device into this clock.
  receive(stamp: string): void {
    const parts = stamp.split("-");
    if (parts.length !== 3 || !/^\d+$/.test(parts[0]) || !/^\d+$/.test(parts[1])) return;
    const rMillis = Number(parts[0]), rCounter = Number(parts[1]);
    const wall = this.now();
    const m = Math.max(wall, this.millis, rMillis);
    if (m === this.millis && m === rMillis) {
      this.counter = Math.max(this.counter, rCounter) + 1;
    } else if (m === this.millis) {
      this.counter++;
    } else if (m === rMillis) {
      this.counter = rCounter + 1;
    } else {
      this.counter = 0;
    }
    this.millis = m;
  }
}

const format = (millis: number, counter: number, node: string) =>
  `${String(millis).padStart(15, "0")}-${String(counter).padStart(6, "0")}-${node}`;

/// Whether stamp [a] is newer than [b]: code-unit order, as Dart's compareTo.
export const newer = (a: string, b: string) => a > b;
