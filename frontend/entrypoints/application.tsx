import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";
import { pageKeyFor, shouldMountInertia } from "../inertiaMount";

// Inertia resolve a página pelo nome, então o bundle não precisa conhecer a
// lista em tempo de compilação.
const pages = import.meta.glob("../pages/**/*.tsx", { eager: true });

// Só monta quando a página é de fato uma página Inertia. Ver
// frontend/inertiaMount.ts para o porquê de essa guarda existir: sem ela, o
// bundle rejeita em toda requisição enquanto a página ERB renderiza normal.
if (shouldMountInertia(pages)) {
  void createInertiaApp({
    resolve: (name: string) => {
      const page = pages[pageKeyFor(name)];
      if (!page) throw new Error(`Pagina Inertia nao encontrada: ${name}`);
      return page;
    },
    setup({ el, App, props }) {
      createRoot(el).render(<App {...props} />);
    },
  });
}
