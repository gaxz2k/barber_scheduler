import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": resolve(import.meta.dirname, "frontend"),
    },
  },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./frontend/test/setup.ts"],
    include: ["frontend/**/*.test.ts", "frontend/**/*.test.tsx"],
    css: false,
    restoreMocks: true,
  },
});
