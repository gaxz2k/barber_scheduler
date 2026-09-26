/**
 * Guarda de montagem do Inertia.
 *
 * `createInertiaApp` assume que existe um elemento com `id="app"` carregando
 * `data-page`. Sem ele, o Inertia rejeita com "Cannot read properties of null
 * (reading 'component')" em toda requisição — e, como a página ERB renderiza
 * normalmente, o visitante não vê nada de errado e o console mostra só uma
 * promessa rejeitada.
 *
 * Hoje o app é server-rendered em ERB, então não existe ponto de montagem. Este
 * módulo deixa a migração começar sem assumir a página: o bundle só monta
 * quando a página for de fato uma página Inertia.
 */

const MOUNT_ID = "app";

/** Chave que o import.meta.glob usa para a página, a partir do component. */
export function pageKeyFor(component: string): string {
  return `../pages/${component}.tsx`;
}

/** Componente da página Inertia atual, ou null se a página não for Inertia. */
export function inertiaPageComponent(
  doc: Pick<Document, "getElementById"> = document,
): string | null {
  const el = doc.getElementById(MOUNT_ID);
  if (!el?.dataset.page) return null;

  try {
    const payload: unknown = JSON.parse(el.dataset.page);
    if (typeof payload !== "object" || payload === null) return null;

    const component = (payload as { component?: unknown }).component;
    return typeof component === "string" ? component : null;
  } catch {
    // data-page malformado é tão inválido quanto ausente: não vale derrubar a
    // página por causa disso, o conteúdo ERB já foi renderizado.
    return null;
  }
}

/** Verdadeiro apenas quando há página Inertia com componente React correspondente. */
export function shouldMountInertia(
  pages: Record<string, unknown>,
  doc: Pick<Document, "getElementById"> = document,
): boolean {
  const component = inertiaPageComponent(doc);
  if (component === null) return false;

  // O component chega como "Booking/Index", mas a chave devolvida pelo
  // import.meta.glob é o caminho relativo "../pages/Booking/Index.tsx" — o
  // mesmo formato usado pelo `resolve` do createInertiaApp. Comparar o
  // component direto contra as chaves faria a guarda nunca montar.
  return pageKeyFor(component) in pages;
}
