<!--
THESIS: Uma mesa operacional de conversas, sem navegação global disputando atenção.
OWN-WORLD: Cards nativos compactos, divisórias ajustáveis e controles RottaWoot de alta densidade.
STORY: O agente encontra a mesma fila do Chatwoot, abre por clique ou arraste e dimensiona até quatro chats completos.
FIRST VIEWPORT: Barra curta, fila rica à esquerda e um chat nativo ocupando toda a altura restante.
FORM: Extensão do mundo estabelecido; modo Operate; um painel por padrão e expansão sob demanda.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
-->
<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { getLastMessage } from 'dashboard/helper/conversationHelper';

const STORAGE_KEY = 'rotta-conversation-focus-workspace-v2';
const route = useRoute();
const store = useStore();
const query = ref('');
const layout = ref(1);
const selectedIds = ref([]);
const activePanelIndex = ref(0);
const panelWidths = ref({});
const draggingId = ref(null);
const dragTargetIndex = ref(null);
const searchInput = ref(null);
const copy = {
  title: 'Central focada',
  subtitle: 'Converse com até quatro clientes em paralelo.',
  layoutLabel: 'Número de conversas visíveis',
  searchLabel: 'Conversas',
  searchPlaceholder: 'Pesquisar conversas...',
  unnamed: 'Sem nome',
  noMessage: 'Sem mensagens recentes',
  addConversation: 'Arraste uma conversa para cá',
  addConversationHelp: 'Ou clique em um cliente na lista.',
  resize: 'Arraste a borda direita para ajustar a largura',
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
const persist = () =>
  localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({
      layout: layout.value,
      selectedIds: selectedIds.value,
      panelWidths: panelWidths.value,
    })
  );
const conversationById = id => conversations.value.find(item => item.id === id);
const conversationName = id =>
  conversationById(id)?.meta?.sender?.name || `Conversa #${id}`;
const panelUrl = id =>
  `/app/accounts/${route.params.accountId}/conversations/${id}?conversationFocusPanel=1`;
const previewText = conversation => {
  const latestMessage = getLastMessage(conversation);
  return latestMessage?.content || copy.noMessage;
};
const previewTime = conversation => {
  const raw =
    conversation.timestamp ||
    conversation.last_activity_at ||
    conversation.lastActivityAt;
  if (!raw) return '';
  const date = new Date(Number(raw) > 1e12 ? Number(raw) : Number(raw) * 1000);
  if (Number.isNaN(date.getTime())) return '';
  return new Intl.DateTimeFormat('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
};
const openConversation = id => {
  const normalizedId = Number(id);
  const existingIndex = selectedIds.value.indexOf(normalizedId);
  if (existingIndex >= 0) {
    activePanelIndex.value = existingIndex;
    return;
  }
  if (selectedIds.value.length < layout.value) {
    selectedIds.value = [...selectedIds.value, normalizedId];
    activePanelIndex.value = selectedIds.value.length - 1;
    return;
  }
  const next = [...selectedIds.value];
  next[Math.min(activePanelIndex.value, layout.value - 1)] = normalizedId;
  selectedIds.value = next;
};
const closeConversation = id => {
  selectedIds.value = selectedIds.value.filter(item => item !== id);
  activePanelIndex.value = Math.max(
    0,
    Math.min(activePanelIndex.value, selectedIds.value.length - 1)
  );
};
const setLayout = size => {
  layout.value = size;
  activePanelIndex.value = Math.min(activePanelIndex.value, size - 1);
};
const startDrag = (event, id) => {
  draggingId.value = Number(id);
  event.dataTransfer.effectAllowed = 'copy';
  event.dataTransfer.setData('text/plain', String(id));
};
const dropConversation = (event, index) => {
  const id = Number(
    event.dataTransfer.getData('text/plain') || draggingId.value
  );
  dragTargetIndex.value = null;
  draggingId.value = null;
  if (!id) return;
  const next = selectedIds.value.filter(item => item !== id);
  next[index] = id;
  selectedIds.value = next.filter(Boolean).slice(0, 4);
  if (index >= layout.value) layout.value = Math.min(4, index + 1);
  activePanelIndex.value = index;
};
const finishResize = (event, id) => {
  const width = Math.round(event.currentTarget.getBoundingClientRect().width);
  if (width >= 340) panelWidths.value = { ...panelWidths.value, [id]: width };
};
const panelStyle = id => {
  const savedWidth = panelWidths.value[id];
  const width =
    savedWidth && visibleIds.value.length > 1
      ? `${savedWidth}px`
      : `${100 / Math.max(1, visibleIds.value.length)}%`;
  return { flexBasis: width, width };
};

watch([layout, selectedIds, panelWidths], persist, { deep: true });
onMounted(async () => {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
    layout.value = Math.min(4, Math.max(1, Number(saved.layout) || 1));
    selectedIds.value = Array.isArray(saved.selectedIds)
      ? saved.selectedIds.map(Number).filter(Boolean).slice(0, 4)
      : [];
    panelWidths.value = saved.panelWidths || {};
  } catch {
    localStorage.removeItem(STORAGE_KEY);
  }
  await store.dispatch('fetchAllConversations', { force: true });
  if (!selectedIds.value.length && conversations.value[0]?.id)
    selectedIds.value = [conversations.value[0].id];
  await nextTick();
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
          :class="{ '!bg-n-brand !text-white': layout === size }"
          :aria-pressed="layout === size"
          :title="`${size} conversa${size > 1 ? 's' : ''}`"
          @click="setLayout(size)"
        >
          <span :class="`layout-icon layout-icon-${size}`" aria-hidden="true">
            <i v-for="cell in size" :key="cell" />
          </span>
          <span>{{ size }}</span>
        </button>
      </div>
    </header>
    <div class="focus-body">
      <aside class="conversation-picker">
        <div class="picker-heading">
          <label for="focus-conversation-search">{{ copy.searchLabel }}</label
          ><span>{{ filteredConversations.length }}</span>
        </div>
        <div class="search-field">
          <span class="i-lucide-search" aria-hidden="true" /><input
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
            class="conversation-card"
            :class="{
              selected: selectedIds.includes(conversation.id),
              dragging: draggingId === conversation.id,
            }"
            draggable="true"
            @click="openConversation(conversation.id)"
            @dragstart="startDrag($event, conversation.id)"
            @dragend="draggingId = null"
          >
            <img
              v-if="conversation.meta?.sender?.thumbnail"
              :src="conversation.meta.sender.thumbnail"
              alt=""
              class="conversation-avatar"
            />
            <span
              v-else
              class="conversation-avatar avatar-fallback"
              aria-hidden="true"
              >{{ (conversation.meta?.sender?.name || '~').slice(0, 1) }}</span
            >
            <span class="conversation-card-body">
              <span class="conversation-card-title"
                ><strong>{{
                  conversation.meta?.sender?.name || copy.unnamed
                }}</strong
                ><time>{{ previewTime(conversation) }}</time></span
              >
              <span class="conversation-preview">{{
                previewText(conversation)
              }}</span>
              <span
                v-if="conversation.labels?.length"
                class="conversation-labels"
                ><span
                  v-for="label in conversation.labels.slice(0, 3)"
                  :key="label"
                  >{{ label }}</span
                ><span v-if="conversation.labels.length > 3"
                  >+{{ conversation.labels.length - 3 }}</span
                ></span
              >
            </span>
            <span v-if="conversation.unreadCount" class="unread-badge">{{
              conversation.unreadCount
            }}</span
            ><span
              class="drag-grip i-lucide-grip-vertical"
              aria-hidden="true"
            />
          </button>
        </div>
      </aside>
      <main class="panel-strip">
        <article
          v-for="(id, index) in visibleIds"
          :key="id"
          class="conversation-panel"
          :class="{
            active: activePanelIndex === index,
            'drop-target': dragTargetIndex === index,
          }"
          :style="panelStyle(id)"
          :title="copy.resize"
          @click="activePanelIndex = index"
          @dragover.prevent="dragTargetIndex = index"
          @dragleave="dragTargetIndex = null"
          @drop.prevent="dropConversation($event, index)"
          @mouseup="finishResize($event, id)"
        >
          <div class="panel-heading">
            <span class="panel-number">{{ index + 1 }}</span
            ><strong>{{ conversationName(id) }}</strong
            ><span class="panel-actions"
              ><span
                class="resize-hint i-lucide-move-horizontal"
                aria-hidden="true" /><button
                type="button"
                :aria-label="`Fechar ${conversationName(id)}`"
                @click.stop="closeConversation(id)"
              >
                <span class="i-lucide-x" aria-hidden="true" /></button
            ></span>
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
          :class="{
            'drop-target': dragTargetIndex === visibleIds.length + slot - 1,
          }"
          @click="searchInput?.focus()"
          @dragover.prevent="dragTargetIndex = visibleIds.length + slot - 1"
          @dragleave="dragTargetIndex = null"
          @drop.prevent="dropConversation($event, visibleIds.length + slot - 1)"
        >
          <span
            class="i-lucide-message-square-plus"
            aria-hidden="true"
          /><strong>{{ copy.addConversation }}</strong
          ><span>{{ copy.addConversationHelp }}</span>
        </button>
      </main>
    </div>
  </section>
</template>

<style scoped>
.focus-workspace {
  --n-background: 255 255 255;
  --n-brand: 37 99 235;
  --n-slate-3: 229 231 235;
  --n-slate-4: 209 213 219;
  --n-slate-5: 156 163 175;
  --n-slate-8: 107 114 128;
  --n-slate-9: 107 114 128;
  --n-slate-10: 75 85 99;
  --n-slate-11: 55 65 81;
  --n-slate-12: 17 24 39;
  --n-alpha-1: 249 250 251;
  --n-alpha-2: 243 244 246;
  --n-alpha-3: 229 231 235;
  display: flex;
  flex-direction: column;
  width: 100%;
  height: 100%;
  min-width: 0;
  background: rgb(var(--n-background));
}
.focus-toolbar {
  min-height: 3.75rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.55rem 0.85rem;
  border-bottom: 1px solid rgb(var(--n-slate-3));
  background: rgb(var(--n-background));
}
.focus-title {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  min-width: 0;
}
.focus-title > span {
  width: 1.25rem;
  height: 1.25rem;
  color: rgb(var(--n-brand));
}
.focus-title h1 {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 600;
}
.focus-title p {
  margin: 0.08rem 0 0;
  font-size: 0.72rem;
  color: rgb(var(--n-slate-10));
}
.layout-switcher {
  display: flex;
  gap: 0.2rem;
  padding: 0.18rem;
  border-radius: 0.75rem;
  background: rgb(var(--n-alpha-2));
}
.layout-switcher button {
  min-width: 2.55rem;
  height: 2rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.3rem;
  border-radius: 0.55rem;
  font-size: 0.72rem;
  color: rgb(var(--n-slate-11));
  transition:
    background-color 0.14s ease,
    color 0.14s ease,
    transform 0.14s ease;
}
.layout-switcher button:hover {
  background: rgb(var(--n-alpha-3));
  transform: translateY(-1px);
}
.layout-icon {
  width: 0.9rem;
  height: 0.75rem;
  display: grid;
  gap: 1px;
  padding: 1px;
  border: 1px solid currentColor;
  border-radius: 2px;
}
.layout-icon-2,
.layout-icon-3,
.layout-icon-4 {
  grid-template-columns: repeat(2, 1fr);
}
.layout-icon i {
  display: block;
  border-radius: 1px;
  background: currentColor;
  opacity: 0.65;
}
.focus-body {
  display: flex;
  flex: 1;
  min-height: 0;
}
.conversation-picker {
  width: 20rem;
  flex: none;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 0.65rem 0.55rem;
  border-right: 1px solid rgb(var(--n-slate-3));
  background: rgb(var(--n-background));
}
.picker-heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 0.2rem;
}
.picker-heading label {
  font-size: 0.78rem;
  font-weight: 600;
}
.picker-heading span {
  min-width: 1.4rem;
  padding: 0.1rem 0.35rem;
  border-radius: 999px;
  text-align: center;
  font-size: 0.65rem;
  background: rgb(var(--n-alpha-2));
  color: rgb(var(--n-slate-10));
}
.search-field {
  position: relative;
}
.search-field > span {
  position: absolute;
  left: 0.65rem;
  top: 50%;
  width: 0.95rem;
  height: 0.95rem;
  transform: translateY(-50%);
  color: rgb(var(--n-slate-9));
}
.search-field input {
  width: 100%;
  height: 2.25rem;
  padding: 0 0.65rem 0 2rem;
  border: 1px solid rgb(var(--n-slate-4));
  border-radius: 0.65rem;
  background: rgb(var(--n-alpha-1));
  outline: none;
  font-size: 0.78rem;
}
.search-field input:focus {
  border-color: rgb(var(--n-brand));
  box-shadow: 0 0 0 2px rgb(var(--n-brand) / 0.16);
}
.conversation-results {
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: auto;
}
.conversation-card {
  position: relative;
  display: grid;
  grid-template-columns: 2.35rem minmax(0, 1fr) auto;
  gap: 0.55rem;
  align-items: center;
  min-height: 4.6rem;
  padding: 0.55rem 0.45rem;
  border-bottom: 1px solid rgb(var(--n-slate-3));
  text-align: left;
  transition:
    background-color 0.13s ease,
    box-shadow 0.13s ease,
    transform 0.13s ease;
}
.conversation-card:hover {
  z-index: 1;
  background: rgb(var(--n-alpha-2));
  box-shadow: inset 3px 0 0 rgb(var(--n-brand));
}
.conversation-card:active {
  transform: scale(0.992);
}
.conversation-card.selected {
  background: rgb(var(--n-brand) / 0.07);
  box-shadow: inset 3px 0 0 rgb(var(--n-brand));
}
.conversation-card.dragging {
  opacity: 0.48;
}
.conversation-avatar {
  width: 2.35rem;
  height: 2.35rem;
  border-radius: 999px;
  object-fit: cover;
  background: rgb(var(--n-alpha-2));
}
.avatar-fallback {
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.8rem;
  font-weight: 600;
}
.conversation-card-body {
  display: flex;
  flex-direction: column;
  gap: 0.18rem;
  min-width: 0;
}
.conversation-card-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.4rem;
}
.conversation-card-title strong {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.78rem;
  font-weight: 600;
}
.conversation-card-title time {
  flex: none;
  font-size: 0.62rem;
  color: rgb(var(--n-slate-9));
}
.conversation-preview {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.7rem;
  color: rgb(var(--n-slate-10));
}
.conversation-labels {
  display: flex;
  gap: 0.22rem;
  overflow: hidden;
}
.conversation-labels span {
  max-width: 7rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding: 0.08rem 0.32rem;
  border: 1px solid rgb(var(--n-slate-4));
  border-radius: 0.35rem;
  font-size: 0.58rem;
  color: rgb(var(--n-slate-11));
  background: rgb(var(--n-alpha-1));
}
.unread-badge {
  min-width: 1.25rem;
  height: 1.25rem;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 0.3rem;
  border-radius: 999px;
  background: rgb(var(--n-brand));
  color: white;
  font-size: 0.62rem;
  font-weight: 600;
}
.drag-grip {
  position: absolute;
  right: 0.12rem;
  bottom: 0.18rem;
  width: 0.8rem;
  height: 0.8rem;
  opacity: 0;
  color: rgb(var(--n-slate-8));
}
.conversation-card:hover .drag-grip {
  opacity: 1;
}
.panel-strip {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: flex;
  align-items: stretch;
  overflow-x: auto;
  overflow-y: hidden;
  background: rgb(var(--n-slate-3));
}
.conversation-panel {
  position: relative;
  flex: none;
  display: flex;
  flex-direction: column;
  min-width: 21.25rem;
  max-width: calc(100% - 1rem);
  min-height: 0;
  resize: horizontal;
  overflow: hidden;
  border-right: 1px solid rgb(var(--n-slate-4));
  background: rgb(var(--n-background));
}
.conversation-panel.active {
  box-shadow: inset 0 3px 0 rgb(var(--n-brand));
}
.conversation-panel.drop-target,
.empty-panel.drop-target {
  outline: 2px solid rgb(var(--n-brand));
  outline-offset: -3px;
  background: rgb(var(--n-brand) / 0.08);
}
.panel-heading {
  height: 2.25rem;
  flex: none;
  display: flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0 0.5rem;
  border-bottom: 1px solid rgb(var(--n-slate-3));
  background: rgb(var(--n-background));
}
.panel-number {
  width: 1.25rem;
  height: 1.25rem;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.35rem;
  font-size: 0.62rem;
  font-weight: 600;
  background: rgb(var(--n-alpha-2));
  color: rgb(var(--n-slate-10));
}
.panel-heading > strong {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.75rem;
}
.panel-actions {
  display: flex;
  align-items: center;
  gap: 0.2rem;
}
.resize-hint {
  width: 0.95rem;
  height: 0.95rem;
  color: rgb(var(--n-slate-8));
}
.panel-heading button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.65rem;
  height: 1.65rem;
  border-radius: 0.45rem;
}
.panel-heading button:hover {
  background: rgb(var(--n-alpha-2));
}
.panel-heading button span {
  width: 0.9rem;
  height: 0.9rem;
}
.conversation-panel iframe {
  flex: 1;
  width: 100%;
  min-height: 0;
  border: 0;
  background: rgb(var(--n-background));
}
.empty-panel {
  flex: 1 0 21.25rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  min-height: 0;
  border: 1px dashed rgb(var(--n-slate-5));
  background: rgb(var(--n-background));
  color: rgb(var(--n-slate-10));
  transition:
    background-color 0.14s ease,
    outline-color 0.14s ease;
}
.empty-panel:hover {
  background: rgb(var(--n-alpha-2));
}
.empty-panel > span:first-child {
  width: 1.4rem;
  height: 1.4rem;
}
.empty-panel strong {
  color: rgb(var(--n-slate-12));
  font-size: 0.8rem;
}
.empty-panel span:last-child {
  font-size: 0.7rem;
}
@media (max-width: 900px) {
  .conversation-picker {
    width: 15rem;
  }
  .conversation-panel {
    min-width: calc(100vw - 15rem);
    max-width: none;
    resize: none;
  }
  .resize-hint {
    display: none;
  }
}
@media (max-width: 620px) {
  .focus-toolbar {
    min-height: 3.4rem;
    padding: 0.45rem 0.55rem;
  }
  .focus-title p,
  .layout-icon {
    display: none;
  }
  .layout-switcher button {
    min-width: 1.85rem;
  }
  .conversation-picker {
    width: 7.5rem;
    padding: 0.45rem 0.35rem;
  }
  .picker-heading span,
  .conversation-card-title time,
  .conversation-preview,
  .conversation-labels,
  .unread-badge {
    display: none;
  }
  .search-field > span {
    display: none;
  }
  .search-field input {
    padding: 0 0.4rem;
    font-size: 0.68rem;
  }
  .conversation-card {
    grid-template-columns: 2rem minmax(0, 1fr);
    gap: 0.35rem;
    min-height: 3.7rem;
    padding: 0.4rem 0.25rem;
  }
  .conversation-avatar {
    width: 2rem;
    height: 2rem;
  }
  .conversation-card-title strong {
    font-size: 0.68rem;
  }
  .conversation-panel {
    min-width: calc(100vw - 7.5rem);
    width: calc(100vw - 7.5rem) !important;
  }
}
</style>
