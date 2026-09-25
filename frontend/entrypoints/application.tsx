import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";

// Inertia resolve a pagina pelo nome, entao o bundle nao precisa conhecer a
// lista em tempo de compilacao.
const pages = import.meta.glob("../pages/**/*.tsx", { eager: true });

void createInertiaApp({
  resolve: (name: string) => {
    const page = pages[`../pages/${name}.tsx`];
    if (!page) throw new Error(`Pagina Inertia nao encontrada: ${name}`);
    return page;
  },
  setup({ el, App, props }) {
    createRoot(el).render(<App {...props} />);
  },
});
