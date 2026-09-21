<!--
THESIS: Uma mesa operacional de conversas, sem navegação global disputando atenção.
OWN-WORLD: Superfícies RottaWoot sóbrias, divisórias finas e controles compactos do sistema existente.
STORY: O agente filtra, fixa até quatro clientes e trabalha neles em paralelo sem abandonar o Chatwoot normal.
FIRST VIEWPORT: Barra operacional no topo, lista compacta à esquerda e painéis de conversa ocupando todo o restante.
FORM: Extensão do mundo estabelecido; modo Operate; decisão confirmada pelo usuário.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
-->
<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';

const STORAGE_KEY = 'rotta-conversation-focus-workspace-v1';
const route = useRoute();
const store = useStore();
const query = ref('');
const layout = ref(2);
const selectedIds = ref([]);
const searchInput = ref(null);
const copy = {
  title: 'Central focada',
  subtitle: 'Até quatro conversas, sem distrações.',
  layoutLabel: 'Número de painéis',
  searchLabel: 'Localizar conversa',
  searchPlaceholder: 'Nome, número ou ID',
  unnamed: 'Sem nome',
  addConversation: 'Adicionar conversa',
  addConversationHelp: 'Escolha um cliente na lista.',
};

const conversations = computed(() => store.getters.getAllConversations || []);
const filteredConversations = computed(() => {
  const needle = query.value.trim().toLocaleLowerCase('pt-BR');
  if (!needle) return conversations.value;
  return conversations.value.filter(conversation => {
    const sender = conversation.meta?.sender || {};
    return [sender.name, sender.phone_number, conversation.id]
      .filter(Boolean)
      .some(value => String(value).toLocaleLowerCase('pt-BR').includes(needle));
  });
});
const visibleIds = computed(() => selectedIds.value.slice(0, layout.value));
const gridClass = computed(() => `layout-${layout.value}`);

const persist = () => {
  localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({ layout: layout.value, selectedIds: selectedIds.value })
  );
};

const selectConversation = id => {
  const normalizedId = Number(id);
  const withoutCurrent = selectedIds.value.filter(
    item => item !== normalizedId
  );
  selectedIds.value = [normalizedId, ...withoutCurrent].slice(0, 4);
};

const closeConversation = id => {
  selectedIds.value = selectedIds.value.filter(item => item !== id);
};

const conversationName = id => {
  const conversation = conversations.value.find(item => item.id === id);
  return conversation?.meta?.sender?.name || `Conversa #${id}`;
};

const panelUrl = id =>
  `/app/accounts/${route.params.accountId}/conversations/${id}?conversationFocusPanel=1`;

watch([layout, selectedIds], persist, { deep: true });

onMounted(async () => {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
    layout.value = Math.min(4, Math.max(1, Number(saved.layout) || 2));
    selectedIds.value = Array.isArray(saved.selectedIds)
      ? saved.selectedIds.map(Number).filter(Boolean).slice(0, 4)
      : [];
  } catch {
    localStorage.removeItem(STORAGE_KEY);
  }

  await store.dispatch('fetchAllConversations', { force: true });
  if (!selectedIds.value.length && conversations.value[0]?.id) {
    selectedIds.value = [conversations.value[0].id];
  }
});
</script>

<template>
  <section class="focus-workspace">
    <header class="focus-toolbar">
      <div class="focus-title">
        <span class="i-lucide-panels-top-left" aria-hidden="true" />
        <div>
          <h1>{{ copy.title }}</h1>
          <p>{{ copy.subtitle }}</p>
        </div>
      </div>
      <div class="layout-switcher" role="group" :aria-label="copy.layoutLabel">
        <button
          v-for="size in 4"
          :key="size"
          type="button"
          :class="{ active: layout === size }"
          :aria-pressed="layout === size"
          @click="layout = size"
        >
          {{ size }}
        </button>
      </div>
    </header>

    <div class="focus-body">
      <aside class="conversation-picker">
        <label for="focus-conversation-search">{{ copy.searchLabel }}</label>
        <div class="search-field">
          <span class="i-lucide-search" aria-hidden="true" />
          <input
            id="focus-conversation-search"
            ref="searchInput"
            v-model="query"
            type="search"
            :placeholder="copy.searchPlaceholder"
          />
        </div>
        <div class="conversation-results">
          <button
            v-for="conversation in filteredConversations"
            :key="conversation.id"
            type="button"
            :class="{ selected: selectedIds.includes(conversation.id) }"
            @click="selectConversation(conversation.id)"
          >
            <strong>{{
              conversation.meta?.sender?.name || copy.unnamed
            }}</strong>
            <span>{{
              conversation.meta?.sender?.phone_number || `#${conversation.id}`
            }}</span>
          </button>
        </div>
      </aside>

      <main class="panel-grid" :class="gridClass">
        <article v-for="id in visibleIds" :key="id" class="conversation-panel">
          <div class="panel-heading">
            <strong>{{ conversationName(id) }}</strong>
            <button
              type="button"
              :aria-label="`Fechar ${conversationName(id)}`"
              @click="closeConversation(id)"
            >
              <span class="i-lucide-x" aria-hidden="true" />
            </button>
          </div>
          <iframe
            :src="panelUrl(id)"
            :title="`Conversa com ${conversationName(id)}`"
            loading="eager"
          />
        </article>
        <button
          v-for="slot in Math.max(0, layout - visibleIds.length)"
          :key="`empty-${slot}`"
          type="button"
          class="empty-panel"
          @click="searchInput?.focus()"
        >
          <span class="i-lucide-message-square-plus" aria-hidden="true" />
          <strong>{{ copy.addConversation }}</strong>
          <span>{{ copy.addConversationHelp }}</span>
        </button>
      </main>
    </div>
  </section>
</template>

<style scoped>
.focus-workspace {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  min-width: 0;
  background: var(--color-n-background);
}
.focus-toolbar {
  min-height: 4rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--color-n-weak);
  background: var(--color-n-surface-1);
}
.focus-title {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  min-width: 0;
}
.focus-title > span {
  width: 1.35rem;
  height: 1.35rem;
  color: var(--color-n-brand);
}
.focus-title h1 {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
}
.focus-title p {
  margin: 0.1rem 0 0;
  font-size: 0.75rem;
  color: var(--color-n-slate-10);
}
.layout-switcher {
  display: flex;
  gap: 0.25rem;
  padding: 0.2rem;
  border-radius: 0.75rem;
  background: var(--color-n-alpha-2);
}
.layout-switcher button {
  width: 2rem;
  height: 2rem;
  border-radius: 0.55rem;
  font-size: 0.8rem;
  color: var(--color-n-slate-11);
}
.layout-switcher button.active {
  background: var(--color-n-brand);
  color: white;
}
.focus-body {
  display: flex;
  flex: 1;
  min-height: 0;
}
.conversation-picker {
  width: 15.5rem;
  flex: none;
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  padding: 0.75rem;
  border-right: 1px solid var(--color-n-weak);
  background: var(--color-n-surface-1);
}
.conversation-picker label {
  font-size: 0.75rem;
  font-weight: 600;
}
.search-field {
  position: relative;
}
.search-field > span {
  position: absolute;
  left: 0.65rem;
  top: 50%;
  width: 1rem;
  height: 1rem;
  transform: translateY(-50%);
  color: var(--color-n-slate-9);
}
.search-field input {
  width: 100%;
  height: 2.35rem;
  padding: 0 0.65rem 0 2rem;
  border: 1px solid var(--color-n-weak);
  border-radius: 0.75rem;
  background: var(--color-n-surface-2);
  outline: none;
}
.search-field input:focus {
  border-color: var(--color-n-brand);
  box-shadow: 0 0 0 2px
    color-mix(in srgb, var(--color-n-brand) 20%, transparent);
}
.conversation-results {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  min-height: 0;
  overflow: auto;
}
.conversation-results button {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.1rem;
  padding: 0.55rem 0.65rem;
  border-radius: 0.65rem;
  text-align: left;
}
.conversation-results button:hover,
.conversation-results button.selected {
  background: var(--color-n-alpha-2);
}
.conversation-results button.selected {
  box-shadow: inset 0 0 0 1px var(--color-n-brand);
}
.conversation-results strong {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.8rem;
}
.conversation-results span {
  font-size: 0.7rem;
  color: var(--color-n-slate-10);
}
.panel-grid {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: grid;
  gap: 1px;
  background: var(--color-n-weak);
}
.panel-grid.layout-1 {
  grid-template-columns: 1fr;
}
.panel-grid.layout-2 {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}
.panel-grid.layout-3 {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}
.panel-grid.layout-4 {
  grid-template-columns: repeat(2, minmax(0, 1fr));
  grid-template-rows: repeat(2, minmax(0, 1fr));
}
.conversation-panel {
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
  background: var(--color-n-surface-1);
}
.panel-heading {
  height: 2.3rem;
  flex: none;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 0.65rem;
  border-bottom: 1px solid var(--color-n-weak);
}
.panel-heading strong {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.75rem;
}
.panel-heading button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.75rem;
  height: 1.75rem;
  border-radius: 0.5rem;
}
.panel-heading button:hover {
  background: var(--color-n-alpha-2);
}
.panel-heading span {
  width: 1rem;
  height: 1rem;
}
.conversation-panel iframe {
  flex: 1;
  width: 100%;
  min-height: 0;
  border: 0;
  background: var(--color-n-surface-1);
}
.empty-panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  min-width: 0;
  min-height: 0;
  background: var(--color-n-surface-1);
  color: var(--color-n-slate-10);
}
.empty-panel > span:first-child {
  width: 1.5rem;
  height: 1.5rem;
}
.empty-panel strong {
  color: var(--color-n-slate-12);
  font-size: 0.85rem;
}
.empty-panel span:last-child {
  font-size: 0.75rem;
}
@media (max-width: 900px) {
  .conversation-picker {
    width: 12rem;
  }
  .panel-grid {
    grid-template-columns: 1fr !important;
    grid-template-rows: 1fr !important;
  }
  .conversation-panel:not(:first-of-type),
  .empty-panel:not(:first-of-type) {
    display: none;
  }
}
@media (max-width: 600px) {
  .focus-toolbar {
    min-height: 3.5rem;
    padding: 0.5rem 0.65rem;
  }
  .focus-title p {
    display: none;
  }
  .conversation-picker {
    width: 7rem;
    padding: 0.5rem;
  }
  .conversation-picker label {
    font-size: 0.68rem;
  }
  .search-field input {
    padding-left: 0.5rem;
    font-size: 0.72rem;
  }
  .search-field > span {
    display: none;
  }
  .conversation-results span {
    display: none;
  }
}
</style>
