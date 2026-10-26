<script lang="ts" module>
  interface Detector {
    detect(source: HTMLVideoElement): Promise<{ rawValue: string }[]>;
  }
  type DetectorClass = new (o: { formats: string[] }) => Detector;

  /// The browser's own QR reader (Chrome on Android, ChromeOS and macOS,
  /// Safari 17+); elsewhere the link is pasted instead.
  export const canScan = () =>
    typeof window !== "undefined" && "BarcodeDetector" in window && !!navigator.mediaDevices?.getUserMedia;
</script>

<script lang="ts">
  import { onMount } from "svelte";

  let { onfound, onclose }: { onfound: (text: string) => void; onclose: () => void } = $props();
  let video: HTMLVideoElement | undefined = $state();
  let error = $state("");

  onMount(() => {
    let stream: MediaStream | null = null;
    let stopped = false;
    (async () => {
      try {
        stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" } });
        if (stopped || !video) return;
        video.srcObject = stream;
        await video.play();
        const detector = new (window as unknown as { BarcodeDetector: DetectorClass }).BarcodeDetector({ formats: ["qr_code"] });
        while (!stopped) {
          const codes = await detector.detect(video);
          if (codes.length) return onfound(codes[0].rawValue);
          await new Promise((r) => setTimeout(r, 250));
        }
      } catch (e) {
        error = e instanceof DOMException && e.name === "NotAllowedError"
          ? "Camera access was refused. Paste the link instead."
          : "The camera could not be used. Paste the link instead.";
      }
    })();
    return () => {
      stopped = true;
      for (const t of stream?.getTracks() ?? []) t.stop();
    };
  });
</script>

<div class="scanner">
  <!-- The preview is for aiming only; the link it finds is filled in below. -->
  <video bind:this={video} muted playsinline aria-label="Camera preview for the QR code"></video>
  <p class="error" role="alert">{error}</p>
  <button type="button" class="text" onclick={onclose}>Stop scanning</button>
</div>
