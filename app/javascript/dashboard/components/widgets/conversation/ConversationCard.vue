<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  getLastMessage,
  hasUnreadIncomingMessage,
  isIncomingMessage,
} from 'dashboard/helper/conversationHelper';
import Avatar from 'next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessagePreview from './MessagePreview.vue';
import InboxName from '../InboxName.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import CardLabels from './conversationCardComponents/CardLabels.vue';
import CardPriorityIcon from 'dashboard/components-next/Conversation/ConversationCard/CardPriorityIcon.vue';
import UnreadBadge from 'dashboard/components-next/Conversation/ConversationCard/UnreadBadge.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import VoiceCallStatus from './VoiceCallStatus.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import { getOriginalAvatarUrl } from 'dashboard/helper/avatarUrl';
import { conversationActivityTimestamp } from 'shared/helpers/timeHelper';

const props = defineProps({
  chat: { type: Object, required: true },
  currentContact: { type: Object, required: true },
  assignee: { type: Object, default: () => ({}) },
  inbox: { type: Object, default: () => ({}) },
  selected: { type: Boolean, default: false },
  isActiveChat: { type: Boolean, default: false },
  showAssignee: { type: Boolean, default: false },
  showInboxName: { type: Boolean, default: false },
  hideThumbnail: { type: Boolean, default: false },
  compact: { type: Boolean, default: false },
});

const emit = defineEmits([
  'click',
  'contextmenu',
  'openContact',
  'selectConversation',
  'deSelectConversation',
]);

const hovered = ref(false);
const { t } = useI18n();

const hasUnread = computed(() => hasUnreadIncomingMessage(props.chat));
const unreadCount = computed(() =>
  hasUnread.value ? Number(props.chat.unread_count || 0) : 0
);
const lastMessageInChat = computed(() => getLastMessage(props.chat));
const lastMessageFromContact = computed(() =>
  isIncomingMessage(lastMessageInChat.value)
);
const typingUsersForConversation = useMapGetter(
  'conversationTypingStatus/getUserList'
);
const isAnyoneTyping = computed(
  () => typingUsersForConversation.value(props.chat.id).length > 0
);
const typingPreview = computed(() => {
  const typingUsers = typingUsersForConversation.value(props.chat.id);
  const contact = typingUsers.find(
    user => user.type === 'Contact' || user.type === 'contact'
  );
  return t('CONVERSATION.TYPING.ONE', {
    user: contact?.name || t('CONVERSATION.CONTACT'),
  });
});

const voiceCallData = computed(() => {
  const last = lastMessageInChat.value;
  if (last?.content_type !== 'voice_call' || !last.call) {
    return { status: null, direction: null };
  }
  return {
    status: last.call.status,
    direction: last.call.direction === 'outgoing' ? 'outbound' : 'inbound',
  };
});

const showMetaSection = computed(() => {
  return (
    props.showInboxName ||
    (props.showAssignee && props.assignee.name) ||
    props.chat.priority
  );
});

const isAgentBotAssignee = computed(
  () => props.chat?.meta?.assignee_type === 'AgentBot'
);

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !props.currentContact?.blocked
);

const showLabelsSection = computed(() => {
  return props.chat.labels?.length > 0 || hasSlaPolicyId.value;
});

const hasKelvinCaioLabel = computed(() =>
  props.chat?.labels?.includes('kelvin-caio')
);

const currentContactAvatarUrl = computed(() =>
  getOriginalAvatarUrl(
    props.currentContact?.avatar_url || props.currentContact?.thumbnail
  )
);

const isPinned = computed(() => {
  const value = props.chat?.custom_attributes?.rotta_pinned;
  return value === true || value === 1 || value === 'true' || value === '1';
});

const messagePreviewClass = computed(() => {
  return [
    hasUnread.value ? 'font-medium text-n-slate-12' : 'text-n-slate-11',
    lastMessageFromContact.value && hasUnread.value
      ? 'rotta-incoming-preview'
      : '',
    !props.compact && hasUnread.value ? 'ltr:pr-4 rtl:pl-4' : '',
    props.compact && hasUnread.value ? 'ltr:pr-6 rtl:pl-6' : '',
  ];
});

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const onSelectConversation = checked => {
  if (checked) {
    emit('selectConversation', props.chat.id, props.inbox.id);
  } else {
    emit('deSelectConversation', props.chat.id, props.inbox.id);
  }
};

const selectedModel = computed({
  get: () => props.selected,
  set: value => onSelectConversation(value),
});

watch(
  () => props.chat.id,
  () => {
    hovered.value = false;
  }
);
</script>

<template>
  <div
    class="relative flex items-start flex-grow-0 flex-shrink-0 w-auto max-w-full min-h-[5.25rem] py-0 cursor-pointer conversation border-b border-n-slate-3 hover:border-n-surface-1 hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3 group hover:z-[1] before:content-[none] before:absolute before:-top-px before:inset-x-0 before:h-px before:bg-n-surface-1 before:pointer-events-none hover:before:content-['']"
    :class="{
      'active animate-card-select bg-n-background !border-n-surface-1':
        isActiveChat,
      'selected bg-n-slate-2 !border-n-surface-1': selected,
      'rotta-kelvin-card': hasKelvinCaioLabel,
      'rotta-pinned-card': isPinned,
      'rotta-incoming-card': lastMessageFromContact && hasUnread,
      'px-0': compact,
      'px-3': !compact,
    }"
    @click="$emit('click', $event)"
    @contextmenu="$emit('contextmenu', $event)"
  >
    <div
      class="relative"
      @mouseenter="onThumbnailHover"
      @mouseleave="onThumbnailLeave"
    >
      <button
        v-if="!hideThumbnail"
        type="button"
        class="rotta-contact-avatar"
        :aria-label="`Abrir perfil de ${currentContact.name}`"
        @click.stop="emit('openContact')"
      >
        <Avatar
          :name="currentContact.name"
          :src="currentContactAvatarUrl"
          :size="44"
          :status="currentContact.availability_status"
          class="rounded-full"
          :class="!showInboxName ? 'mt-3' : 'mt-7'"
          hide-offline-status
        />
      </button>
      <label
        v-if="!hideThumbnail && (hovered || selected)"
        class="rotta-conversation-select flex items-center justify-center rounded-full cursor-pointer absolute z-10"
        @click.stop
      >
        <Checkbox v-model="selectedModel" />
      </label>
    </div>
    <div
      class="rotta-conversation-content px-0 py-2.5 flex-1 min-w-0 border-line"
    >
      <div class="rotta-card-heading">
        <div class="rotta-card-heading-main min-w-0 flex-1">
          <div
            v-if="showMetaSection"
            class="flex items-center min-w-0 gap-1"
            :class="{
              'ltr:ml-2 rtl:mr-2': !compact,
              'mx-2': compact,
            }"
          >
            <InboxName
              v-if="showInboxName"
              :inbox="inbox"
              class="flex-1 min-w-0"
            />
            <div
              class="flex items-baseline gap-2 flex-shrink-0"
              :class="{
                'flex-1 justify-between': !showInboxName,
              }"
            >
              <span
                v-if="showAssignee && assignee.name"
                class="text-n-slate-11 text-xs font-medium leading-3 py-0.5 px-0 inline-flex items-center gap-px truncate"
              >
                <Icon
                  :icon="
                    isAgentBotAssignee ? 'i-lucide-bot' : 'i-lucide-user-round'
                  "
                  class="size-3 text-n-slate-11 flex-shrink-0"
                />
                <span class="truncate">{{ assignee.name }}</span>
              </span>
              <CardPriorityIcon
                :priority="chat.priority"
                class="flex-shrink-0 !size-3.5"
              />
            </div>
          </div>
          <h4
            class="conversation--user text-sm my-0 mx-2 capitalize pt-0.5 text-ellipsis overflow-hidden whitespace-nowrap min-w-0 text-n-slate-12"
            :class="hasUnread ? 'font-semibold' : 'font-medium'"
          >
            {{ currentContact.name }}
          </h4>
        </div>
        <div class="rotta-card-meta">
          <Icon
            v-if="isPinned"
            v-tooltip="'Conversa fixada'"
            icon="i-lucide-pin"
            class="size-3.5 text-n-brand"
            :aria-label="$t('CONVERSATION.HEADER.PINNED')"
          />
          <TimeAgo
            :last-activity-timestamp="conversationActivityTimestamp(chat)"
            :created-at-timestamp="chat.created_at"
            :conversation-id="chat.id"
            only-last-activity
          />
        </div>
      </div>
      <div class="rotta-card-preview-row">
        <p
          v-if="isAnyoneTyping"
          class="my-0 mx-2 leading-6 h-6 flex-1 min-w-0 overflow-hidden text-ellipsis whitespace-nowrap text-sm text-n-emerald-11 font-medium"
        >
          {{ typingPreview }}
        </p>
        <VoiceCallStatus
          v-else-if="voiceCallData.status"
          key="voice-status-row"
          :status="voiceCallData.status"
          :direction="voiceCallData.direction"
          :message-preview-class="messagePreviewClass"
        />
        <MessagePreview
          v-else-if="lastMessageInChat"
          key="message-preview"
          :message="lastMessageInChat"
          class="my-0 mx-2 leading-6 h-6 flex-1 min-w-0 text-sm"
          :class="messagePreviewClass"
        />
        <p
          v-else
          key="no-messages"
          class="text-n-slate-11 text-sm my-0 mx-2 leading-6 h-6 flex-1 min-w-0 overflow-hidden text-ellipsis whitespace-nowrap"
          :class="messagePreviewClass"
        >
          <fluent-icon
            size="16"
            class="-mt-0.5 align-middle inline-block text-n-slate-10"
            icon="info"
          />
          <span class="mx-0.5">
            {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
          </span>
        </p>
        <UnreadBadge
          v-if="hasUnread"
          :count="unreadCount"
          class="shrink-0 ltr:mr-3 rtl:ml-3"
        />
      </div>
      <CardLabels
        v-if="showLabelsSection"
        :conversation-labels="chat.labels"
        class="rotta-conversation-labels mt-1 mx-2 mb-0"
      >
        <template v-if="hasSlaPolicyId" #before>
          <SLACardLabel :chat="chat" class="ltr:mr-1 rtl:ml-1" />
        </template>
      </CardLabels>
    </div>
  </div>
</template>

<style scoped>
.rotta-kelvin-card {
  box-shadow:
    inset 0 0 0 1px rgb(192 38 211 / 38%),
    0 1px 3px rgb(192 38 211 / 10%);
  background: rgb(192 38 211 / 3%);
}

.rotta-pinned-card {
  background: color-mix(in srgb, var(--color-n-brand, #2563eb) 4%, transparent);
}

.rotta-incoming-card {
  background: color-mix(in srgb, var(--color-n-emerald-3) 48%, transparent);
}

.rotta-incoming-card .conversation--user {
  font-weight: 700;
}

.rotta-incoming-preview {
  color: var(--color-n-emerald-11) !important;
  font-weight: 650;
}

.dark .rotta-incoming-card {
  background: color-mix(in srgb, var(--color-n-emerald-9) 14%, transparent);
}

.rotta-conversation-content {
  display: flex;
  flex-direction: column;
  min-width: 0;
  gap: 0.125rem;
}

.rotta-contact-avatar {
  display: block;
  padding: 0;
  background: transparent;
  border: 0;
  border-radius: 999px;
  cursor: pointer;
}

.rotta-contact-avatar:focus-visible {
  outline: 2px solid var(--color-n-brand, #2563eb);
  outline-offset: 3px;
}

.rotta-conversation-select {
  top: 0.25rem;
  left: 1.25rem;
  width: 1.5rem;
  height: 1.5rem;
  background: rgb(255 255 255 / 88%);
  box-shadow: 0 1px 4px rgb(0 0 0 / 16%);
}

.rotta-card-heading {
  display: flex;
  align-items: flex-start;
  min-width: 0;
  gap: 0.5rem;
}

.rotta-card-meta {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  min-width: max-content;
  gap: 0.125rem;
  padding-top: 0.125rem;
}

.rotta-card-preview-row {
  display: flex;
  align-items: center;
  min-width: 0;
  min-height: 1.5rem;
  gap: 0.25rem;
}

.rotta-conversation-labels {
  min-height: 1.25rem;
  max-width: 100%;
  overflow: hidden;
}

.rotta-conversation-labels :deep(> div) {
  min-width: 0;
  overflow: hidden;
}

.rotta-conversation-labels :deep(.label) {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
