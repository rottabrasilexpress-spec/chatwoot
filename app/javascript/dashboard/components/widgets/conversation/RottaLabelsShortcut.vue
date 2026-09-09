<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';
import { useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const LABEL_ORDER_STORAGE_KEY = 'rotta-label-order';

const LABEL_META = {
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
  'clientes-fechados': { title: 'Clientes fechados 🤝', color: '#059669' },
  'kelvin-caio': { title: 'KELVIN / CAIO', color: '#c026d3' },
  arquivado: { title: 'Arquivado', color: '#991b1b' },
};

const DEFAULT_LABEL_ORDER = [
  'primeiro-contato',
  'segundo-contato',
  'terceiro-contato',
  'ultimo-contato',
  'orcamento-feito',
  'orcamento-tentativa-2',
  'orcamento-tentativa-3',
  'orcamento-tentativa-4',
  'orcamento-5-dias',
  'orcamento-10-dias',
  'orcamento-15-dias',
  'contato-instantaneo',
  'orcamento-instantaneo',
  'clientes-fechados',
  'kelvin-caio',
  'arquivado',
];

const { isAdmin } = useAdmin();
const route = useRoute();
const store = useStore();
const isOpen = ref(false);
const search = ref('');
const labelOrder = ref([]);
const draggedLabelTitle = ref('');
const labelsPanelTitle = 'Etiquetas do cliente';
const searchPlaceholder = 'Pesquisar etiquetas';
const searchLabelsAriaLabel = 'Pesquisar etiquetas';
const allLabelsAriaLabel = 'Todas as etiquetas';
const emptyLabelsText = 'Nenhuma etiqueta encontrada.';
const reorderHint = 'Arraste para reordenar';
const manageLabelsText = 'Gerenciar etiquetas';
const dragLabelTitle = 'Arraste para reordenar';

const {
  accountLabels,
  savedLabels,
  addLabelToConversation,
  removeLabelFromConversation,
} = useConversationLabels();

const hasKelvinCaio = computed(() => savedLabels.value.includes('kelvin-caio'));
const settingsLabelsPath = computed(
  () => `/app/accounts/${route.params.accountId}/settings/labels`
);
const selectedCountLabel = computed(
  () => `${savedLabels.value.length} selecionada(s)`
);
const selectedLabels = computed(() =>
  savedLabels.value.map(
    title =>
      accountLabels.value.find(label => label.title === title) || { title }
  )
);

const defaultLabelRank = title => {
  const rank = DEFAULT_LABEL_ORDER.indexOf(title);
  return rank >= 0 ? rank : DEFAULT_LABEL_ORDER.length + 1;
};

const labelTitle = label => {
  const title = typeof label === 'string' ? label : label?.title;
  const fallback = String(title || 'outra etiqueta')
    .replace(/[-_]+/g, ' ')
    .replace(/\b\w/g, character => character.toUpperCase());
  return LABEL_META[title]?.title || fallback;
};

const labelColor = label =>
  label?.color || LABEL_META[label?.title]?.color || '#64748b';

const labelCount = label => Number(label?.contacts_count || 0);

const orderedLabels = computed(() => {
  const manualRanks = new Map(
    labelOrder.value.map((title, index) => [title, index])
  );

  return [...accountLabels.value].sort((first, second) => {
    const firstRank = manualRanks.has(first.title)
      ? manualRanks.get(first.title)
      : defaultLabelRank(first.title);
    const secondRank = manualRanks.has(second.title)
      ? manualRanks.get(second.title)
      : defaultLabelRank(second.title);

    if (firstRank !== secondRank) return firstRank - secondRank;
    return labelTitle(first).localeCompare(labelTitle(second), 'pt-BR');
  });
});

const filteredLabels = computed(() => {
  const query = search.value.trim().toLocaleLowerCase('pt-BR');
  if (!query) return orderedLabels.value;

  return orderedLabels.value.filter(label =>
    `${label.title} ${labelTitle(label)}`
      .toLocaleLowerCase('pt-BR')
      .includes(query)
  );
});

const persistLabelOrder = () => {
  window.localStorage.setItem(
    LABEL_ORDER_STORAGE_KEY,
    JSON.stringify(labelOrder.value)
  );
};

const loadLabelOrder = () => {
  try {
    const storedOrder = JSON.parse(
      window.localStorage.getItem(LABEL_ORDER_STORAGE_KEY) || '[]'
    );
    if (Array.isArray(storedOrder)) labelOrder.value = storedOrder;
  } catch (error) {
    labelOrder.value = [];
  }
};

const toggle = async () => {
  isOpen.value = !isOpen.value;
  if (isOpen.value) {
    await store.dispatch('labels/get');
  }
};

const close = () => {
  isOpen.value = false;
};

const toggleLabel = label => {
  if (savedLabels.value.includes(label.title)) {
    removeLabelFromConversation(label.title);
  } else {
    addLabelToConversation(label);
  }
};

const startDragging = label => {
  draggedLabelTitle.value = label.title;
};

const dropLabel = targetLabel => {
  const sourceTitle = draggedLabelTitle.value;
  if (!sourceTitle || sourceTitle === targetLabel.title) return;

  const currentOrder = orderedLabels.value.map(label => label.title);
  const sourceIndex = currentOrder.indexOf(sourceTitle);
  const targetIndex = currentOrder.indexOf(targetLabel.title);
  if (sourceIndex < 0 || targetIndex < 0) return;

  currentOrder.splice(sourceIndex, 1);
  currentOrder.splice(targetIndex, 0, sourceTitle);
  labelOrder.value = currentOrder;
  persistLabelOrder();
  draggedLabelTitle.value = '';
};

onMounted(loadLabelOrder);
</script>

<template>
  <div
    v-on-clickaway="close"
    class="relative flex items-center min-w-0 gap-1 rotta-labels-shortcut"
  >
    <div
      v-if="selectedLabels.length"
      class="rotta-labels-visible"
      :aria-label="$t('CONVERSATION.CARD.SHOW_LABELS')"
    >
      <span
        v-for="label in selectedLabels"
        :key="label.title"
        class="rotta-label-visible"
        :style="{
          '--label-color': labelColor(label),
        }"
        :title="labelTitle(label)"
      >
        {{ labelTitle(label) }}
      </span>
    </div>
    <Button
      v-tooltip="'Etiquetas'"
      size="sm"
      variant="ghost"
      color="slate"
      icon="i-lucide-tags"
      label="Etiquetas"
      class="whitespace-nowrap rounded-md"
      :class="{
        'rotta-labels-shortcut--priority': hasKelvinCaio,
      }"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="toggle"
    />

    <div
      v-if="isOpen"
      class="rotta-labels-menu absolute z-[100] top-full mt-2 ltr:right-0 rtl:left-0 w-[min(21rem,calc(100vw-1rem))] p-2 border rounded-xl shadow-xl bg-n-surface-1 border-n-strong"
      role="menu"
    >
      <div class="flex items-center justify-between gap-3 px-1 pb-2">
        <span class="text-xs font-medium text-n-slate-12">
          {{ labelsPanelTitle }}
        </span>
        <span class="text-xxs text-n-slate-11">
          {{ selectedCountLabel }}
        </span>
      </div>

      <input
        v-model="search"
        type="search"
        autocomplete="off"
        class="search-input rotta-labels-search"
        :placeholder="searchPlaceholder"
        :aria-label="searchLabelsAriaLabel"
      />

      <div
        class="rotta-labels-scroll"
        role="group"
        :aria-label="allLabelsAriaLabel"
      >
        <div
          v-for="label in filteredLabels"
          :key="label.title"
          class="rotta-label-row"
          :class="{
            'rotta-label-row--priority': label.title === 'kelvin-caio',
          }"
          draggable="true"
          @dragstart="startDragging(label)"
          @dragover.prevent
          @drop="dropLabel(label)"
        >
          <button
            type="button"
            role="menuitemcheckbox"
            class="rotta-label-option"
            :aria-checked="savedLabels.includes(label.title)"
            @click="toggleLabel(label)"
          >
            <span
              class="rotta-label-dot"
              :style="{ backgroundColor: labelColor(label) }"
              aria-hidden="true"
            />
            <span class="rotta-label-name" :title="labelTitle(label)">
              {{ labelTitle(label) }}
            </span>
            <span
              class="rotta-label-count"
              :title="`${labelCount(label)} clientes`"
            >
              {{ labelCount(label) }}
            </span>
            <Icon
              v-if="savedLabels.includes(label.title)"
              icon="i-lucide-check"
              class="rotta-label-check size-4"
              aria-hidden="true"
            />
          </button>
          <span
            class="rotta-label-drag"
            :title="dragLabelTitle"
            aria-hidden="true"
          >
            <Icon icon="i-lucide-grip-vertical" class="size-4" />
          </span>
        </div>

        <p v-if="!filteredLabels.length" class="rotta-labels-empty">
          {{ emptyLabelsText }}
        </p>
      </div>

      <div
        class="flex items-center justify-between gap-2 px-1 pt-2 mt-1 border-t border-n-weak"
      >
        <span class="text-xxs text-n-slate-11">{{ reorderHint }}</span>
        <a
          v-if="isAdmin"
          :href="settingsLabelsPath"
          class="text-xxs font-medium text-n-brand hover:underline"
        >
          {{ manageLabelsText }}
        </a>
      </div>
    </div>
  </div>
</template>

<style scoped>
.rotta-labels-menu {
  max-height: min(36rem, calc(100dvh - 5.5rem));
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.rotta-labels-visible {
  display: flex;
  min-width: 0;
  max-width: min(32rem, 48vw);
  align-items: center;
  gap: 0.3rem;
  overflow: hidden;
}

.rotta-label-visible {
  display: inline-flex;
  min-width: 0;
  max-width: 12rem;
  align-items: center;
  padding: 0.2rem 0.5rem;
  overflow: hidden;
  color: var(--color-n-slate-12, #0f172a);
  font-size: 0.6875rem;
  font-weight: 600;
  line-height: 1rem;
  text-overflow: ellipsis;
  white-space: nowrap;
  background: color-mix(in srgb, var(--label-color) 14%, transparent);
  border: 1px solid color-mix(in srgb, var(--label-color) 48%, transparent);
  border-radius: 999px;
}

.rotta-labels-shortcut--priority {
  color: #c026d3;
  outline: 1px solid rgb(192 38 211 / 45%);
  box-shadow: 0 0 0 2px rgb(192 38 211 / 10%);
}

.rotta-labels-shortcut--priority:hover {
  background: rgb(192 38 211 / 12%);
}

.rotta-labels-search {
  flex: none;
  min-height: 2.5rem;
  margin-bottom: 0.35rem;
}

.rotta-labels-scroll {
  min-height: 0;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-gutter: stable;
}

.rotta-label-row {
  display: flex;
  align-items: center;
  min-height: 2.75rem;
  border-radius: 0.5rem;
}

.rotta-label-row:hover,
.rotta-label-row--priority {
  background: rgb(37 99 235 / 6%);
}

.rotta-label-option {
  display: flex;
  align-items: center;
  min-width: 0;
  flex: 1;
  gap: 0.5rem;
  min-height: 2.75rem;
  padding: 0.5rem 0.45rem 0.5rem 0.55rem;
  color: var(--color-n-slate-12);
  text-align: start;
  cursor: pointer;
}

.rotta-label-option:focus-visible,
.rotta-label-drag:focus-visible {
  outline: 2px solid var(--color-n-brand, #2563eb);
  outline-offset: -2px;
}

.rotta-label-dot {
  width: 0.65rem;
  height: 0.65rem;
  flex: none;
  border: 1px solid rgb(0 0 0 / 10%);
  border-radius: 999px;
}

.rotta-label-name {
  min-width: 0;
  flex: 1;
  overflow: hidden;
  font-size: 0.8125rem;
  line-height: 1.25rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-label-count {
  min-width: 1.6rem;
  padding: 0 0.3rem;
  border-radius: 999px;
  background: var(--color-n-slate-3, #e5e7eb);
  color: var(--color-n-slate-11, #64748b);
  font-size: 0.6875rem;
  line-height: 1.15rem;
  text-align: center;
}

.rotta-label-check {
  flex: none;
  color: var(--color-n-brand, #2563eb);
}

.rotta-label-drag {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  min-height: 2.75rem;
  flex: none;
  color: var(--color-n-slate-10, #94a3b8);
  cursor: grab;
}

.rotta-label-drag:active {
  cursor: grabbing;
}

.rotta-labels-empty {
  padding: 1rem 0.5rem;
  margin: 0;
  color: var(--color-n-slate-11, #64748b);
  font-size: 0.75rem;
  text-align: center;
}

@media (max-width: 640px) {
  .rotta-labels-visible {
    max-width: calc(100vw - 8rem);
  }

  .rotta-labels-menu {
    position: fixed;
    inset-inline: 0.5rem;
    inset-block-start: 3.5rem;
    width: auto;
    max-height: calc(100dvh - 4.5rem);
  }

  .rotta-label-option,
  .rotta-label-drag {
    min-height: 2.9rem;
  }

  .rotta-label-option {
    padding-inline: 0.65rem;
  }
}
</style>
