import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { railsPublicOutputDir, viteOutDir } from "@/viteOutputDir";

const root = resolve(import.meta.dirname, "..");
const configPath = resolve(root, "config/vite.json");
const publicDir = resolve(root, "public");

describe("diretório de saída do Vite", () => {
  // Regressão do 500 em development: config/vite.json declarava `vite-dev`
  // enquanto o vite.config.ts computava `vite-development`. O build escrevia o
  // manifesto num lugar e o vite_ruby procurava em outro, então toda página
  // respondia 500 com ViteRuby::MissingEntrypointError. O CI não pegava porque
  // em test os dois lados dizem `vite-test` e em production os dois dizem
  // `vite` — só development divergia, e o CI só constrói o alvo de test.
  it.each(["development", "test", "production"])(
    "escreve no mesmo diretório que o vite_ruby procura em %s",
    (env) => {
      // railsPublicOutputDir é literalmente a leitura que o vite_ruby faz.
      const expected = resolve(publicDir, railsPublicOutputDir(env, configPath));

      expect(viteOutDir(env, configPath, publicDir)).toBe(expected);
    },
  );

  it.each([
    ["development", "vite-dev"],
    ["test", "vite-test"],
    ["production", "vite"],
  ])("usa %s -> public/%s", (env, expected) => {
    expect(railsPublicOutputDir(env, configPath)).toBe(expected);
  });

  it("não volta a computar o nome por conta própria no vite.config.ts", () => {
    const source = readFileSync(resolve(root, "vite.config.ts"), "utf8");

    // A regra quebrada era um template string por ambiente. Se alguém
    // reintroduzir um nome calculado aqui, este exemplo falha mesmo que, por
    // acaso, os valores voltem a bater hoje.
    expect(source).not.toMatch(/vite-\$\{/);
    expect(source).toMatch(/viteOutDir/);
  });
});
