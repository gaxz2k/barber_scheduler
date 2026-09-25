/**
 * Contrato entre o Rails e o frontend React.
 *
 * Cada interface espelha o shape exato que a action envia no Inertia page
 * object. Se o Ruby mudar e o tipo não acompanhar, o typecheck quebra.
 */

export interface ServiceOption {
  id: number;
  name: string;
  durationMinutes: number;
}

export interface ProfessionalOption {
  id: number;
  name: string;
}

export interface SlotOption {
  value: string;
  label: string;
}

export interface CarouselPhoto {
  id: number;
  imageUrl: string;
  caption: string | null;
}

export type BookingStep = "service" | "professional" | "schedule";

export interface SharedProps {
  csrfToken: string;
}

export interface IndexPageProps extends SharedProps {
  photos: CarouselPhoto[];
  services: ServiceOption[];
  step: BookingStep;
  selectedService: ServiceOption | null;
  selectedProfessional: ProfessionalOption | null;
  selectedDate: string;
  minDate: string;
  maxDate: string;
  slots: SlotOption[];
  errors: string[];
  appointment: {
    startAt: string | null;
    clientName: string;
    clientPhone: string;
  };
}

export interface ConfirmationPageProps extends SharedProps {
  eyebrow: string;
  title: string;
  message: string;
  serviceName: string;
  professionalName: string;
  startAtLabel: string;
  status: string;
  clientName: string;
  clientPhone: string;
}
