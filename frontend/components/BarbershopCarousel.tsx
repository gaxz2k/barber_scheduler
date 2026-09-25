import { useCallback, useEffect, useId, useRef, useState } from "react";
import type { KeyboardEvent } from "react";
import type { CarouselPhoto } from "@/types/booking";

const AUTOPLAY_MS = 6_000;

function prefersReducedMotion(): boolean {
  if (!window.matchMedia) return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

interface BarbershopCarouselProps {
  photos: CarouselPhoto[];
}

export function BarbershopCarousel({ photos }: BarbershopCarouselProps) {
  const titleId = useId();
  const [index, setIndex] = useState(0);
  const [userPaused, setUserPaused] = useState(prefersReducedMotion);
  const [failed, setFailed] = useState<ReadonlySet<number>>(() => new Set());
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  const total = photos.length;

  const go = useCallback(
    (next: number) => {
      if (total === 0) return;
      setIndex(((next % total) + total) % total);
    },
    [total]
  );

  const stop = useCallback(() => {
    if (timer.current !== null) {
      clearInterval(timer.current);
      timer.current = null;
    }
  }, []);

  // O autoplay só roda quando o visitante não pediu menos movimento e não
  // pausou manualmente. `force` permite o play explícito pelo botão.
  useEffect(() => {
    if (total < 2 || userPaused) {
      stop();
      return;
    }
    timer.current = setInterval(() => setIndex((current) => (current + 1) % total), AUTOPLAY_MS);
    return stop;
  }, [total, userPaused, stop]);

  const onKeyDown = useCallback(
    (event: KeyboardEvent<HTMLDivElement>) => {
      if (event.key === "ArrowRight") {
        event.preventDefault();
        go(index + 1);
      } else if (event.key === "ArrowLeft") {
        event.preventDefault();
        go(index - 1);
      }
    },
    [go, index]
  );

  if (total === 0) {
    return (
      <div className="barbershop-carousel barbershop-carousel--empty" role="status">
        <div className="barbershop-carousel__empty-icon" aria-hidden="true">
          ✦
        </div>
        <strong>Novas fotos em breve</strong>
        <span>Estamos preparando um tour do espaço da Barbearia Senhor R.</span>
      </div>
    );
  }

  const current = photos[index] ?? photos[0];
  const broken = failed.has(current?.id ?? -1);

  return (
    <section className="barbershop-carousel" aria-labelledby={titleId}>
      <div className="barbershop-carousel__header">
        <div>
          <div className="eyebrow">Conheça a barbearia</div>
          <h2 id={titleId}>Um espaço feito para você</h2>
        </div>
        <div className="barbershop-carousel__controls">
          <button
            type="button"
            className="barbershop-carousel__button"
            onClick={() => setUserPaused((paused) => !paused)}
            aria-label={userPaused ? "Retomar carrossel" : "Pausar carrossel"}
            aria-pressed={userPaused}
          >
            {userPaused ? "▶" : "Ⅱ"}
          </button>
          <button
            type="button"
            className="barbershop-carousel__button"
            onClick={() => go(index - 1)}
            aria-label="Foto anterior"
          >
            ←
          </button>
          <button
            type="button"
            className="barbershop-carousel__button"
            onClick={() => go(index + 1)}
            aria-label="Próxima foto"
          >
            →
          </button>
        </div>
      </div>

      <div
        className="barbershop-carousel__viewport"
        tabIndex={0}
        role="region"
        aria-roledescription="carrossel"
        aria-label="Fotos da Barbearia Senhor R"
        onKeyDown={onKeyDown}
        onMouseEnter={stop}
        onMouseLeave={() => undefined}
        onFocus={stop}
      >
        <div className="barbershop-carousel__track" style={{ transform: `translateX(-${index * 100}%)` }}>
          {photos.map((photo, position) => (
            <figure
              key={photo.id}
              className="barbershop-carousel__slide"
              role="group"
              aria-roledescription="slide"
              aria-label={`Foto ${position + 1} de ${total}`}
              aria-hidden={position === index ? "false" : "true"}
            >
              <div className="barbershop-carousel__image-wrap">
                {failed.has(photo.id) ? null : (
                  <img
                    src={photo.imageUrl}
                    alt={photo.caption ?? "Foto da Barbearia Senhor R"}
                    loading={position === 0 ? "eager" : "lazy"}
                    onError={() => setFailed((prev) => new Set(prev).add(photo.id))}
                  />
                )}
                {failed.has(photo.id) && (
                  <div className="barbershop-carousel__image-fallback">
                    <span aria-hidden="true">▧</span>
                    <strong>Foto indisponível</strong>
                    <span>Tente novamente mais tarde.</span>
                  </div>
                )}
              </div>
              {photo.caption ? <figcaption>{photo.caption}</figcaption> : null}
            </figure>
          ))}
        </div>
      </div>

      <div className="barbershop-carousel__status" role="status" aria-live="polite" aria-atomic="true">
        {broken
          ? "Uma das fotos não pôde ser carregada."
          : `Foto ${index + 1} de ${total}`}
      </div>
    </section>
  );
}
