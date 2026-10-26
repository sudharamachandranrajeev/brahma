// Builds the web app into ../server/public, where the Worker serves it as
// static assets next to /api.
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { createHash } from "node:crypto";
import { readdirSync, readFileSync } from "node:fs";
import { defineConfig, type Plugin } from "vite";

const here = new URL(".", import.meta.url).pathname;

/// Writes sw.js with the exact list of built files, versioned by their
/// content, so a new deploy replaces the cached shell in one step.
function serviceWorker(): Plugin {
  return {
    name: "bhojana-service-worker",
    apply: "build",
    generateBundle(_, bundle) {
      const hash = createHash("sha256");
      const built = Object.values(bundle)
        .filter((f) => !f.fileName.endsWith(".map"))
        .map((f) => {
          hash.update(f.fileName).update(f.type === "chunk" ? f.code : f.source);
          return f.fileName;
        });
      const files = readdirSync(`${here}public`).filter((f) => !f.startsWith("_") && !f.startsWith("."));
      for (const f of files) hash.update(f).update(readFileSync(`${here}public/${f}`));
      const shell = ["/", ...built.filter((f) => f !== "index.html"), ...files].map((f) => (f === "/" ? f : `/${f}`));
      const source = readFileSync(`${here}src/sw.js`, "utf8")
        .replace("__VERSION__", hash.digest("hex").slice(0, 16))
        .replace("__SHELL__", JSON.stringify(shell));
      this.emitFile({ type: "asset", fileName: "sw.js", source });
    },
  };
}

export default defineConfig({
  root: "src",
  publicDir: "../public",
  // The Svelte config sits next to this file (svelte-check reads it there).
  plugins: [svelte({ configFile: `${here}svelte.config.js` }), serviceWorker()],
  build: {
    outDir: "../../server/public",
    emptyOutDir: true,
    target: "es2022",
  },
  server: {
    // `npm run dev` here, `npm run dev` (wrangler) in server/: the API is proxied.
    proxy: { "/api": "http://127.0.0.1:8787" },
  },
});
