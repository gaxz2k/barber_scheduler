import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";
import { railsEnv, viteOutDir } from "./frontend/viteOutputDir";

// O vite_rails cuida do dev server e do proxy para o Rails; aqui servimos
// apenas os assets compilados.
//
// O ambiente e o diretório de saída NÃO são decididos neste arquivo:
// `railsEnv` e `viteOutDir` aplicam a mesma resolução que o railties e o
// vite_ruby aplicam. Ver frontend/viteOutputDir.ts para o porquê dessa fonte
// única existir.
const configPath = resolve(import.meta.dirname, "config/vite.json");
const publicDir = resolve(import.meta.dirname, "public");

export default defineConfig({
  plugins: [react()],
  root: resolve(import.meta.dirname, "frontend"),
  base: "/vite/",
  resolve: {
    alias: {
      "@": resolve(import.meta.dirname, "frontend"),
    },
  },
  build: {
    manifest: true,
    emptyOutDir: true,
    outDir: viteOutDir(railsEnv(), configPath, publicDir),
    rollupOptions: {
      input: resolve(import.meta.dirname, "frontend/entrypoints/application.tsx"),
    },
  },
});
