import { describe, expect, it } from "vitest";
import { inertiaPageComponent, pageKeyFor, shouldMountInertia } from "@/inertiaMount";

function element(page?: string): Pick<Document, "getElementById"> {
  return {
    getElementById: () =>
      page === undefined
        ? null
        : ({ dataset: { page } } as unknown as HTMLElement),
  };
}

// A página React que existiria para "Booking/Index". Manter o mesmo objeto nos
// exemplos é o que torna a guarda observável: com `pages` vazio, `key in pages`
// é sempre false e a asserção "não monta" passa mesmo com a guarda removida.
const PAGES = { "../pages/Booking/Index.tsx": {} };

describe("guarda de montagem do Inertia", () => {
  // Regressão: o entrypoint chamava createInertiaApp incondicionalmente. Como
  // nenhuma view tem id="app" nem data-page, o Inertia rejeitava com
  // "Cannot read properties of null (reading 'component')" em toda requisição
  // — com a página ERB renderizada por cima, ou seja, invisível para o
  // visitante e fácil de perder em review.
  it("não monta quando não existe elemento #app", () => {
    expect(shouldMountInertia(PAGES, element())).toBe(false);
  });

  it("não monta quando #app existe mas não tem data-page", () => {
    expect(shouldMountInertia(PAGES, element(""))).toBe(false);
  });

  it("não monta quando data-page não declara component", () => {
    expect(inertiaPageComponent(element(JSON.stringify({ props: {} })))).toBeNull();
  });

  it("não monta quando o component não é string", () => {
    expect(inertiaPageComponent(element(JSON.stringify({ component: 42 })))).toBeNull();
  });

  it("não monta sem ponto de montagem mesmo com a página React disponível", () => {
    // A página EXISTE, então só a ausência do #app impede a montagem. É este
    // exemplo que quebra se a guarda for removida.
    expect(shouldMountInertia(PAGES, element())).toBe(false);
    expect(shouldMountInertia(PAGES, element(""))).toBe(false);
  });

  it("não monta quando não existe a página React correspondente", () => {
    // Aqui o ponto de montagem existe e é válido; quem impede é a página ausente.
    const doc = element(JSON.stringify({ component: "Outra/Pagina" }));

    expect(shouldMountInertia(PAGES, doc)).toBe(false);
  });

  it("monta quando há #app com data-page e a página existe", () => {
    const page = JSON.stringify({ component: "Booking/Index" });

    expect(shouldMountInertia(PAGES, element(page))).toBe(true);
  });

  it("monta quando a página React existe mas o component tem subpasta", () => {
    // O component do Inertia é "Booking/Index" e a chave do glob é
    // "../pages/Booking/Index.tsx". Comparar o component direto contra as chaves
    // faria a guarda nunca montar, em silêncio.
    const page = JSON.stringify({ component: "Admin/Photos/Index" });
    const pages = { [pageKeyFor("Admin/Photos/Index")]: {} };

    expect(shouldMountInertia(pages, element(page))).toBe(true);
  });

  it("gera a chave na mesma forma que o resolve do createInertiaApp", () => {
    expect(pageKeyFor("Booking/Index")).toBe("../pages/Booking/Index.tsx");
  });

  it("sobrevive a data-page malformado sem derrubar a página", () => {
    // O conteúdo ERB já foi renderizado; uma promessa rejeitada aqui é pior
    // que simplesmente não montar.
    expect(inertiaPageComponent(element("{ nao é json"))).toBeNull();
  });

  it("sobrevive a data-page que não é objeto", () => {
    expect(inertiaPageComponent(element('"apenas uma string"'))).toBeNull();
    expect(inertiaPageComponent(element("null"))).toBeNull();
  });
});
