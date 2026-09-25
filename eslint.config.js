import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import tseslint from "typescript-eslint";

const TYPED_FILES = ["frontend/**/*.{ts,tsx}", "vite.config.ts", "vitest.config.ts"];

export default tseslint.config(
  {
    ignores: [
      "node_modules/**",
      "public/assets/**",
      // Bundle compilado: é saída de build, não código-fonte para lint.
      "public/vite/**",
      "public/vite-dev/**",
      "public/vite-test/**",
      "tmp/**",
      // Código de terceiros vendorizado: não é nosso para corrigir.
      "vendor/**",
      // JS legado do Rails (Stimulus, service worker) fica fora do lint de
      // TypeScript. Sai do escopo quando o React cobrir as telas.
      "app/javascript/**",
      "app/views/pwa/**",
    ],
  },
  // O lint sem tipos cobre o resto do repositório, para não ficar burro.
  {
    ...js.configs.recommended,
    files: ["**/*.js", "**/*.mjs"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: { ...globals.browser, ...globals.node },
    },
  },
  // As regras que exigem informação de tipo valem apenas no escopo do
  // TypeScript; aplicá-las ao JS do Rails quebra o lint.
  ...tseslint.configs.recommendedTypeChecked.map((config) => ({
    ...config,
    files: TYPED_FILES,
  })),
  {
    files: TYPED_FILES,
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    plugins: { "react-hooks": reactHooks },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "@typescript-eslint/consistent-type-imports": "error",
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
    },
  },
  {
    files: ["**/*.test.{ts,tsx}", "frontend/test/**/*.ts"],
    rules: {
      "@typescript-eslint/no-non-null-assertion": "off",
    },
  }
);
