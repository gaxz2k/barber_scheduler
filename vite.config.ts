import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";

// O vite_rails cuida do dev server e do proxy para o Rails; aqui servimos
// apenas os assets compilados.
//
// O diretório de saída precisa acompanhar o RAILS_ENV: o vite_ruby lê o
// manifesto de public/vite-<env> em cada ambiente, e um manifesto único
// quebraria os specs de request em test.
const railsEnv = process.env.RAILS_ENV ?? "development";
const outDir = railsEnv === "production" ? "vite" : `vite-${railsEnv}`;

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
    outDir: resolve(import.meta.dirname, "public", outDir),
    rollupOptions: {
      input: resolve(import.meta.dirname, "frontend/entrypoints/application.tsx"),
    },
  },
});
