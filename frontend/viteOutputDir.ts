import { readFileSync } from "node:fs";
import { resolve } from "node:path";

/**
 * Contrato entre o vite_ruby (Ruby) e o build do Vite (JavaScript).
 *
 * O vite_ruby lê `publicOutputDir` de config/vite.json e procura o manifesto
 * em `public/<publicOutputDir>`. Se o lado JavaScript decidir o nome do
 * diretório por conta própria, os dois divergem e toda página responde 500 com
 * ViteRuby::MissingEntrypointError — sem que o build ou a suíte falem, porque a
 * divergência costuma aparecer só em development e o CI só constrói o alvo de
 * test.
 *
 * Por isso o nome vem de uma fonte só: o config/vite.json que o Ruby lê, e com
 * a mesma regra de resolução que o Ruby aplica.
 */

/** Default do vite_ruby, usado quando nem `all` nem o ambiente declaram `publicOutputDir`. */
export const DEFAULT_PUBLIC_OUTPUT_DIR = "vite";

type ViteSection = { publicOutputDir?: string };
type ViteRailsConfig = Record<string, ViteSection | undefined>;

/**
 * Resolve o `publicOutputDir` exatamente como o vite_ruby resolve.
 *
 * O vite_ruby faz `config.fetch("all", {}).merge(config.fetch(mode, {}))`: a
 * seção "all" entra primeiro e a do ambiente sobrescreve. Ler só a seção do
 * ambiente diverge sempre que `publicOutputDir` estiver em "all" — que é o caso
 * de produção, onde não há seção própria e o valor do "all" é o que vale.
 */
export function railsPublicOutputDir(env: string, configPath: string): string {
  const config = JSON.parse(readFileSync(configPath, "utf8")) as ViteRailsConfig;

  const merged: ViteSection = { ...config.all, ...config[env] };

  return merged.publicOutputDir ?? DEFAULT_PUBLIC_OUTPUT_DIR;
}

/** Caminho absoluto do diretório de saída do Vite para o ambiente. */
export function viteOutDir(env: string, configPath: string, publicDir: string): string {
  return resolve(resolve(publicDir), railsPublicOutputDir(env, configPath));
}

/**
 * Ambiente do Rails, resolvido como o railties resolve.
 *
 * `Rails.env` é `ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence ||
 * "development"`. Dois detalhes do `presence` do ActiveSupport que `||` em
 * JavaScript não reproduz, e que importam porque os dois lados precisam cair
 * no mesmo diretório:
 *
 * - String vazia: `||` já trata `""` como falsy, então isso bate.
 * - String só com espaços: `presence` usa `blank?`, e `"  "` é blank no Ruby.
 *   Em JavaScript `"  "` é truthy, então `||` a aceitaria e o build iria para
 *   `public/vite/` enquanto o Ruby procuraria em `public/vite-test/` — o mesmo
 *   ViteRuby::MissingEntrypointError de 500, de novo, agora por causa de um
 *   espaço em uma variável de ambiente.
 *
 * Por isso a escolha passa por `trim()`: o que é só espaço é descartado como se
 * estivesse ausente, igual ao Ruby.
 */
export function railsEnv(env = process.env): string {
  const candidatos = [env.RAILS_ENV, env.RACK_ENV, "development"];

  return (
    candidatos.find(
      (valor): valor is string =>
        typeof valor === "string" && valor.trim() !== "",
    ) ?? "development"
  );
}
