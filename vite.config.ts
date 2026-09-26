import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";
import { viteOutDir } from "./frontend/viteOutputDir";

// O vite_rails cuida do dev server e do proxy para o Rails; aqui servimos
// apenas os assets compilados.
//
// O diretório de saída NÃO é decidido neste arquivo: `viteOutDir` lê o mesmo
// config/vite.json que o vite_ruby lê. Ver frontend/viteOutputDir.ts para o porquê
// de essa fonte única existir.
const railsEnv = process.env.RAILS_ENV ?? "development";
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
    outDir: viteOutDir(railsEnv, configPath, publicDir),
    rollupOptions: {
      input: resolve(import.meta.dirname, "frontend/entrypoints/application.tsx"),
    },
  },
});
