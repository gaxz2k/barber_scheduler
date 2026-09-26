import { describe, expect, it } from "vitest";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { railsPublicOutputDir, viteOutDir } from "@/viteOutputDir";

const root = resolve(import.meta.dirname, "..");
const configPath = resolve(root, "config/vite.json");
const publicDir = resolve(root, "public");

function configWith(content: unknown): string {
  const dir = mkdtempSync(join(tmpdir(), "vite-config-"));
  const path = join(dir, "vite.json");
  writeFileSync(path, JSON.stringify(content), "utf8");

  return path;
}

describe("diretório de saída do Vite", () => {
  // Regressão do 500 em development: config/vite.json declarava `vite-dev`
  // enquanto o vite.config.ts computava `vite-development`. O build escrevia o
  // manifesto num lugar e o vite_ruby procurava em outro, então toda página
  // respondia 500 com ViteRuby::MissingEntrypointError. O CI não pegava porque
  // em test os dois lados dizem `vite-test` e em production os dois dizem
  // `vite` — só development divergia, e o CI só constrói o alvo de test.
  //
  // Os valores esperados são literais, não recalculados pela função: comparar
  // a função com ela mesma passaria mesmo com a lógica errada.
  it.each([
    ["development", "vite-dev"],
    ["test", "vite-test"],
    ["production", "vite"],
  ])("resolve %s para public/%s", (env, expected) => {
    expect(railsPublicOutputDir(env, configPath)).toBe(expected);
  });

  it.each([
    ["development", "vite-dev"],
    ["test", "vite-test"],
    ["production", "vite"],
  ])("escreve o build de %s em public/%s", (env, expected) => {
    expect(viteOutDir(env, configPath, publicDir)).toBe(join(publicDir, expected));
  });

  it("usa o publicOutputDir da seção all quando o ambiente não declara", () => {
    // O vite_ruby faz config.fetch("all", {}).merge(config.fetch(mode, {})).
    // Ler só a seção do ambiente resolve "vite" aqui, enquanto o Ruby resolve
    // o valor do "all" — e a divergência volta a derrubar development em
    // qualquer configuração que use "all".
    const path = configWith({ all: { publicOutputDir: "vite-tudo" }, test: {} });

    expect(railsPublicOutputDir("test", path)).toBe("vite-tudo");
  });

  it("deixa a seção do ambiente sobrepor a seção all", () => {
    const path = configWith({
      all: { publicOutputDir: "vite-tudo" },
      test: { publicOutputDir: "vite-especifico" },
    });

    expect(railsPublicOutputDir("test", path)).toBe("vite-especifico");
  });

  it("ignora a seção all em ambiente que declara o seu próprio", () => {
    const path = configWith({
      all: { publicOutputDir: "vite-tudo" },
      development: { publicOutputDir: "vite-dev" },
    });

    expect(railsPublicOutputDir("development", path)).toBe("vite-dev");
  });

  it("cai no default quando nem all nem o ambiente declaram", () => {
    const path = configWith({ test: {} });

    expect(railsPublicOutputDir("test", path)).toBe("vite");
  });

  it("não deixa outra chave da seção all contaminar a resolução", () => {
    // "all" também carrega sourceCodeDir e friends; só publicOutputDir vale.
    const path = configWith({ all: { sourceCodeDir: "frontend", port: 3036 } });

    expect(railsPublicOutputDir("test", path)).toBe("vite");
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
