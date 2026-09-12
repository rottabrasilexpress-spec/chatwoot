<script setup>
import { computed, ref, watch, inject } from 'vue';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { hasUnreadIncomingMessage } from 'dashboard/helper/conversationHelper';
import ConversationCard from './widgets/conversation/ConversationCard.vue';
import ConversationCardExpanded from 'dashboard/components-next/Conversation/ConversationCard/ConversationCardExpanded.vue';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import ConversationContextMenu from './widgets/conversation/contextMenu/Index.vue';
import ConversationAPI from 'dashboard/api/inbox/conversation';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  source: { type: Object, required: true },
  teamId: { type: [String, Number], default: 0 },
  label: { type: String, default: '' },
  conversationType: { type: String, default: '' },
  foldersId: { type: [String, Number], default: 0 },
  showAssignee: { type: Boolean, default: false },
  showExpanded: { type: Boolean, default: false },
});

const router = useRouter();
const store = useStore();

const selectConversation = inject('selectConversation');
const deSelectConversation = inject('deSelectConversation');
const assignLabels = inject('assignLabels');
const removeLabels = inject('removeLabels');
const updateConversationStatus = inject('updateConversationStatus');
const toggleContextMenu = inject('toggleContextMenu');
const markAsUnread = inject('markAsUnread');
const markAsRead = inject('markAsRead');
const assignPriority = inject('assignPriority');
const isConversationSelected = inject('isConversationSelected');
const deleteConversation = inject('deleteConversation');
const togglePinned = inject('togglePinned');

// --- Context menu state (shared by both layouts) ---
const showContextMenu = ref(false);
const contextMenu = ref({ x: null, y: null });

// Reset context menu state when the row is recycled to a different conversation.
watch(
  () => props.source.id,
  () => {
    if (showContextMenu.value) {
      toggleContextMenu(false);
    }
    showContextMenu.value = false;
    contextMenu.value = { x: null, y: null };
  }
);

const currentChat = useMapGetter('getSelectedChat');
const inboxesList = useMapGetter('inboxes/getInboxes');
const activeInbox = useMapGetter('getSelectedInbox');
const accountId = useMapGetter('getCurrentAccountId');
const currentUser = useMapGetter('getCurrentUser');

const chatMetadata = computed(() => props.source.meta || {});
const assignee = computed(() => chatMetadata.value.assignee || {});
const senderId = computed(() => chatMetadata.value.sender?.id);

const currentContact = computed(() =>
  senderId.value ? store.getters['contacts/getContact'](senderId.value) : {}
);

const isActiveChat = computed(() => currentChat.value.id === props.source.id);

const inbox = computed(() => {
  const inboxId = props.source.inbox_id;
  return inboxId ? store.getters['inboxes/getInbox'](inboxId) : {};
});

const showInboxName = computed(
  () => !activeInbox.value && inboxesList.value.length > 1
);
const isInboxView = computed(() => !!activeInbox.value);
const showAssigneeForExpandedCard = computed(
  () => props.showExpanded || props.showAssignee
);

const conversationPath = computed(() =>
  frontendURL(
    conversationUrl({
      accountId: accountId.value,
      activeInbox: activeInbox.value,
      id: props.source.id,
      label: props.label,
      teamId: props.teamId,
      conversationType: props.conversationType,
      foldersId: props.foldersId,
    })
  )
);

const onCardClick = e => {
  const path = conversationPath.value;
  if (!path) return;

  if (e.metaKey || e.ctrlKey) {
    e.preventDefault();
    window.open(
      `${window.chatwootConfig.hostURL}${path}`,
      '_blank',
      'noopener,noreferrer'
    );
    return;
  }

  if (isActiveChat.value) return;
  router.push({ path });
};

const onContactClick = () => {
  if (!senderId.value || !accountId.value) return;

  router.push({
    path: frontendURL(`accounts/${accountId.value}/contacts/${senderId.value}`),
  });
};

const onExpandedSelect = checked => {
  if (checked) {
    selectConversation(props.source.id, inbox.value.id);
  } else {
    deSelectConversation(props.source.id, inbox.value.id);
  }
};

const openContextMenu = e => {
  e.preventDefault();
  toggleContextMenu(true);
  contextMenu.value.x = e.pageX || e.clientX;
  contextMenu.value.y = e.pageY || e.clientY;
  showContextMenu.value = true;
};

const closeContextMenu = () => {
  toggleContextMenu(false);
  showContextMenu.value = false;
  contextMenu.value.x = null;
  contextMenu.value.y = null;
};

const onUpdateConversation = (status, snoozedUntil) => {
  closeContextMenu();
  updateConversationStatus(props.source.id, status, snoozedUntil);
};

const onAssignLabel = label => {
  assignLabels([label.title], [props.source.id]);
};

const onRemoveLabel = label => {
  removeLabels([label.title], [props.source.id]);
};

const onMarkAsUnread = () => {
  markAsUnread(props.source.id);
  closeContextMenu();
};

const onMarkAsRead = () => {
  markAsRead(props.source.id);
  closeContextMenu();
};

const onAssignPriority = priority => {
  assignPriority(priority, props.source.id);
  closeContextMenu();
};

const onDeleteConversation = () => {
  deleteConversation(props.source.id);
  closeContextMenu();
};

const onTogglePinned = () => {
  togglePinned(props.source.id);
  closeContextMenu();
};

const onArchiveConversation = () => {
  assignLabels(['arquivado'], [props.source.id]);
  updateConversationStatus(props.source.id, 'resolved', null);
  closeContextMenu();
};

const isPinned = computed(() => {
  const value = props.source.custom_attributes?.rotta_pinned;
  return value === true || value === 1 || value === 'true' || value === '1';
});

const hasUnreadMessages = computed(() =>
  hasUnreadIncomingMessage(props.source)
);

const canRequestAttention = computed(() => {
  const configuredId = window.chatwootConfig?.rottaAttentionRequesterUserId;
  return (
    Boolean(configuredId) &&
    String(currentUser.value?.id) === String(configuredId)
  );
});

const onRequestAttention = async conversationId => {
  try {
    await ConversationAPI.requestAttention(conversationId);
    useAlert('Solicitação enviada para o agente Caio.');
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        'Não foi possível solicitar atenção para esta conversa.'
    );
  }
};
</script>

<template>
  <!-- Expanded layout: wide screen + expanded setting -->
  <ConversationCardExpanded
    v-if="showExpanded"
    :chat="source"
    :current-contact="currentContact"
    :assignee="assignee"
    :inbox="inbox"
    :selected="isConversationSelected(source.id)"
    :is-active-chat="isActiveChat"
    :show-assignee="showAssigneeForExpandedCard"
    :show-inbox-name="showInboxName"
    :is-inbox-view="isInboxView"
    @select-conversation="onExpandedSelect"
    @de-select-conversation="onExpandedSelect"
    @click="onCardClick"
    @open-contact="onContactClick"
    @contextmenu="openContextMenu"
  />

  <!-- Default (condensed) layout -->
  <ConversationCard
    v-else
    :chat="source"
    :current-contact="currentContact"
    :assignee="assignee"
    :inbox="inbox"
    :selected="isConversationSelected(source.id)"
    :is-active-chat="isActiveChat"
    :show-assignee="showAssignee"
    :show-inbox-name="showInboxName"
    @click="onCardClick"
    @open-contact="onContactClick"
    @contextmenu="openContextMenu"
    @select-conversation="selectConversation"
    @de-select-conversation="deSelectConversation"
  />

  <!-- Shared context menu for both layouts -->
  <ContextMenu
    v-if="showContextMenu"
    :x="contextMenu.x"
    :y="contextMenu.y"
    @close="closeContextMenu"
  >
    <ConversationContextMenu
      :status="source.status"
      :priority="source.priority"
      :chat-id="source.id"
      :has-unread-messages="hasUnreadMessages"
      :conversation-labels="source.labels"
      :pinned="isPinned"
      :conversation-url="conversationPath"
      :can-request-attention="canRequestAttention"
      @update-conversation="onUpdateConversation"
      @assign-label="onAssignLabel"
      @remove-label="onRemoveLabel"
      @mark-as-unread="onMarkAsUnread"
      @mark-as-read="onMarkAsRead"
      @assign-priority="onAssignPriority"
      @delete-conversation="onDeleteConversation"
      @toggle-pinned="onTogglePinned"
      @archive-conversation="onArchiveConversation"
      @request-attention="onRequestAttention"
      @close="closeContextMenu"
    />
  </ContextMenu>
</template>
