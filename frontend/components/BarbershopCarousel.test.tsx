import { describe, expect, it, vi } from "vitest";
import { render, screen, act, fireEvent } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { CarouselPhoto } from "@/types/booking";
import { BarbershopCarousel } from "@/components/BarbershopCarousel";

function photo(id: number, caption: string | null = `Foto ${id}`): CarouselPhoto {
  return { id, imageUrl: `/rails/active_storage/disk/photo-${id}`, caption };
}

function renderCarousel(photos: CarouselPhoto[] = [photo(1), photo(2), photo(3)]) {
  return render(<BarbershopCarousel photos={photos} />);
}

describe("BarbershopCarousel", () => {
  it("mostra a primeira foto e anuncia a posição", () => {
    renderCarousel();

    expect(screen.getByRole("region", { name: /fotos da barbearia/i })).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent("Foto 1 de 3");
  });

  it("avança e volta com os botões de controle", async () => {
    const user = userEvent.setup();
    renderCarousel();

    await user.click(screen.getByRole("button", { name: /próxima foto/i }));
    expect(screen.getByRole("status")).toHaveTextContent("Foto 2 de 3");

    await user.click(screen.getByRole("button", { name: /foto anterior/i }));
    expect(screen.getByRole("status")).toHaveTextContent("Foto 1 de 3");
  });

  it("dá a volta no fim da lista", async () => {
    const user = userEvent.setup();
    renderCarousel();

    await user.click(screen.getByRole("button", { name: /foto anterior/i }));

    expect(screen.getByRole("status")).toHaveTextContent("Foto 3 de 3");
  });

  it("navega com as setas do teclado", async () => {
    const user = userEvent.setup();
    renderCarousel();
    const viewport = screen.getByRole("region", { name: /fotos da barbearia/i });
    viewport.focus();

    await user.keyboard("{ArrowRight}");
    expect(screen.getByRole("status")).toHaveTextContent("Foto 2 de 3");

    await user.keyboard("{ArrowLeft}");
    expect(screen.getByRole("status")).toHaveTextContent("Foto 1 de 3");
  });

  it("pausa e retoma pelo botão, com aria-pressed coerente", async () => {
    const user = userEvent.setup();
    renderCarousel();
    const pause = screen.getByRole("button", { name: /pausar carrossel/i });

    expect(pause).toHaveAttribute("aria-pressed", "false");
    await user.click(pause);
    expect(pause).toHaveAttribute("aria-pressed", "true");
    expect(pause).toHaveAccessibleName(/retomar carrossel/i);

    await user.click(pause);
    expect(pause).toHaveAttribute("aria-pressed", "false");
  });

  it("não faz autoplay quando o visitante prefere menos movimento", () => {
    const reduced = vi.fn(
      (query: string) =>
        ({
          matches: true,
          media: query,
          onchange: null,
          addListener: () => undefined,
          removeListener: () => undefined,
          addEventListener: () => undefined,
          removeEventListener: () => undefined,
          dispatchEvent: () => false,
        }) as MediaQueryList
    );
    vi.spyOn(window, "matchMedia").mockImplementation(reduced);
    vi.useFakeTimers();

    renderCarousel();
    act(() => {
      // 7s passa um tick de 6s sem completar um ciclo inteiro de 3 fotos,
      // então "voltar ao 1" não pode acontecer por aritmética.
      vi.advanceTimersByTime(7_000);
    });

    // A preferência precisa ter sido consultada de fato, senão este exemplo
    // passaria mesmo sem a lógica de reduced-motion.
    expect(reduced).toHaveBeenCalledWith("(prefers-reduced-motion: reduce)");
    expect(screen.getByRole("status")).toHaveTextContent("Foto 1 de 3");
    vi.useRealTimers();
  });

  it("avança sozinho quando o autoplay está liberado", () => {
    vi.useFakeTimers();

    renderCarousel();
    act(() => {
      vi.advanceTimersByTime(6_000);
    });

    expect(screen.getByRole("status")).toHaveTextContent("Foto 2 de 3");
    vi.useRealTimers();
  });

  it("marca apenas a foto visível para leitores de tela", () => {
    const { container } = renderCarousel();
    const slides = container.querySelectorAll(".barbershop-carousel__slide");

    expect(slides[0]).toHaveAttribute("aria-hidden", "false");
    expect(slides[1]).toHaveAttribute("aria-hidden", "true");
  });

  it("mostra fallback quando a imagem falha", () => {
    const { container } = renderCarousel();
    const image = container.querySelector("img");
    expect(image).not.toBeNull();

    // fireEvent percorre a árvore do React, então o onError do componente roda.
    fireEvent.error(image as HTMLImageElement);

    expect(screen.getByText(/foto indisponível/i)).toBeVisible();
    expect(screen.getByRole("status")).toHaveTextContent(/não pôde ser carregada/i);
  });

  it("usa a legenda como texto alternativo, com fallback acessível", () => {
    renderCarousel([photo(1, "Cadeira de barbear"), photo(2, null)]);

    expect(screen.getByAltText("Cadeira de barbear")).toBeInTheDocument();
    expect(screen.getByAltText(/foto da barbearia/i)).toBeInTheDocument();
  });

  it("mostra o estado vazio quando não há fotos", () => {
    renderCarousel([]);

    expect(screen.getByText(/novas fotos em breve/i)).toBeInTheDocument();
    expect(screen.queryByRole("region", { name: /fotos da barbearia/i })).not.toBeInTheDocument();
  });
});
