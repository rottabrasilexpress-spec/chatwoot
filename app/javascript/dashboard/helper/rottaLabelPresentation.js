import { computed, ref } from 'vue';

export const LABEL_META = {
  'primeiro-contato': { title: 'Primeiro contato', color: '#16a34a' },
  'segundo-contato': { title: 'Segundo contato', color: '#f59e0b' },
  'terceiro-contato': { title: 'Terceiro contato', color: '#3b82f6' },
  'ultimo-contato': { title: 'Último contato ❌', color: '#dc2626' },
  'orcamento-feito': { title: 'Orçamento feito ✅', color: '#16a34a' },
  'orcamento-tentativa-2': {
    title: 'Orçamento tentativa 2',
    color: '#f59e0b',
  },
  'orcamento-tentativa-3': {
    title: 'Orçamento tentativa 3',
    color: '#3b82f6',
  },
  'orcamento-tentativa-4': {
    title: 'Orçamento tentativa 4 ❌',
    color: '#dc2626',
  },
  'orcamento-5-dias': { title: 'Orçamento 5 dias', color: '#06b6d4' },
  'orcamento-10-dias': { title: 'Orçamento 10 dias', color: '#4f46e5' },
  'orcamento-15-dias': { title: 'Orçamento 15 dias', color: '#7c3aed' },
  'contato-instantaneo': {
    title: 'Contato instantâneo 🫶',
    color: '#e11d48',
  },
  'orcamento-instantaneo': {
    title: 'Orçamento instantâneo 💰',
    color: '#f97316',
  },
  'emitir-contrato': { title: 'Emitir Contrato', color: '#7c3aed' },
  'clientes-fechados': { title: 'Clientes fechados 🤝', color: '#059669' },
  finalizados: { title: 'FINALIZADOS', color: '#dc2626' },
  'caio-atencao': { title: 'Caio Atenção', color: '#f59e0b' },
  kelvin: { title: 'Kelvin', color: '#c026d3' },
  'kelvin-caio': { title: 'KELVIN / CAIO', color: '#c026d3' },
  arquivado: { title: 'Arquivado', color: '#991b1b' },
};

export const LABEL_PRESENTATION_OPTIONS = [
  {
    value: 'square',
    label: 'Quadrado',
    description: 'Formato atual, com cantos discretos.',
  },
  {
    value: 'round',
    label: 'Redondo',
    description: 'Cantos totalmente arredondados para leitura rápida.',
  },
  {
    value: 'crisp',
    label: 'Nítido',
    description: 'Contraste e contorno reforçados sem aumentar o volume.',
  },
  {
    value: 'message-border',
    label: 'Contorno da mensagem',
    description: 'A cor da etiqueta contorna o balão da conversa.',
  },
];

export const DEFAULT_LABEL_PRESENTATION = 'square';
const LABEL_PRESENTATION_VALUES = new Set(
  LABEL_PRESENTATION_OPTIONS.map(option => option.value)
);
const presentationState = ref(DEFAULT_LABEL_PRESENTATION);
let presentationStorageKey = '';

const getPresentationStorageKey = () => {
  if (typeof window === 'undefined') return '';

  const accountId = window.location.pathname.match(
    /\/app\/accounts\/([^/]+)/
  )?.[1];
  return `rotta-label-presentation:${accountId || 'default'}`;
};

const readStoredPresentation = () => {
  if (typeof window === 'undefined') return DEFAULT_LABEL_PRESENTATION;

  try {
    const stored = window.localStorage.getItem(
      getPresentationStorageKey() || 'rotta-label-presentation:default'
    );
    return LABEL_PRESENTATION_VALUES.has(stored)
      ? stored
      : DEFAULT_LABEL_PRESENTATION;
  } catch (error) {
    return DEFAULT_LABEL_PRESENTATION;
  }
};

const ensurePresentationLoaded = () => {
  const nextStorageKey = getPresentationStorageKey();
  if (nextStorageKey === presentationStorageKey) return;

  presentationStorageKey = nextStorageKey;
  presentationState.value = readStoredPresentation();
};

ensurePresentationLoaded();

if (typeof window !== 'undefined') {
  window.addEventListener('storage', event => {
    if (event.key !== getPresentationStorageKey()) return;

    presentationState.value = LABEL_PRESENTATION_VALUES.has(event.newValue)
      ? event.newValue
      : DEFAULT_LABEL_PRESENTATION;
  });
}

export const useLabelPresentation = () => {
  ensurePresentationLoaded();

  const setPresentation = value => {
    const nextPresentation = LABEL_PRESENTATION_VALUES.has(value)
      ? value
      : DEFAULT_LABEL_PRESENTATION;

    presentationState.value = nextPresentation;

    if (typeof window === 'undefined') return;

    try {
      window.localStorage.setItem(
        presentationStorageKey || 'rotta-label-presentation:default',
        nextPresentation
      );
    } catch (error) {
      // Keep the current session usable when storage is unavailable.
    }
  };

  return {
    presentation: computed(() => presentationState.value),
    setPresentation,
  };
};

const titleCaseLabel = value =>
  String(value || 'outra etiqueta')
    .replace(/[-_]+/g, ' ')
    .replace(/\b\w/g, character => character.toUpperCase());

export const getLabelPresentationTitle = label => {
  const title = typeof label === 'string' ? label : label?.title;
  return LABEL_META[title]?.title || titleCaseLabel(title);
};

export const getLabelPresentationColor = label => {
  const title = typeof label === 'string' ? label : label?.title;
  return label?.color || LABEL_META[title]?.color || '#64748b';
};

export const getLabelFilterOptions = labels => [
  {
    value: '',
    label: 'Filtrar por etiqueta',
    icon: 'i-lucide-tags',
  },
  ...labels
    .filter(label => label?.title)
    .map(label => ({
      value: label.title,
      label: getLabelPresentationTitle(label),
      color: getLabelPresentationColor(label),
    })),
];
