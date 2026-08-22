<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessagePreview from './MessagePreview.vue';
import VoiceCallStatus from './VoiceCallStatus.vue';
import UnreadBadge from './UnreadBadge.vue';

const props = defineProps({
  lastMessage: { type: Object, default: null },
  voiceCallStatus: { type: String, default: '' },
  voiceCallDirection: { type: String, default: '' },
  unreadCount: { type: Number, default: 0 },
  showExpandedPreview: { type: Boolean, default: false },
  conversationId: { type: [String, Number], default: null },
});

const typingUsersForConversation = useMapGetter(
  'conversationTypingStatus/getUserList'
);
const { t } = useI18n();
const isAnyoneTyping = computed(
  () =>
    props.conversationId &&
    typingUsersForConversation.value(props.conversationId).length > 0
);
const typingPreview = computed(() => {
  const typingUsers = props.conversationId
    ? typingUsersForConversation.value(props.conversationId)
    : [];
  const contact = typingUsers.find(
    user => user.type === 'Contact' || user.type === 'contact'
  );
  return t('CONVERSATION.TYPING.ONE', {
    user: contact?.name || t('CONVERSATION.CONTACT'),
  });
});
</script>

<template>
  <div
    class="grid grid-cols-[1fr_auto] gap-1.5"
    :class="props.showExpandedPreview ? 'items-end' : 'items-center'"
  >
    <span v-if="isAnyoneTyping" class="text-n-emerald-11 font-medium truncate">
      {{ typingPreview }}
    </span>
    <VoiceCallStatus
      v-else-if="props.voiceCallStatus"
      key="voice-status-row"
      :status="props.voiceCallStatus"
      :direction="props.voiceCallDirection"
      :class="props.unreadCount > 0 ? 'text-n-slate-12' : 'text-n-slate-11'"
    />
    <MessagePreview
      v-else-if="props.lastMessage"
      key="message-preview"
      :message="props.lastMessage"
      :multi-line="props.showExpandedPreview"
      :class="props.unreadCount > 0 ? 'text-n-slate-12' : 'text-n-slate-11'"
    />
    <span
      v-else
      key="no-messages"
      class="inline-grid grid-flow-col auto-cols-max items-center gap-1 text-body-main"
      :class="props.unreadCount > 0 ? 'text-n-slate-12' : 'text-n-slate-11'"
    >
      <Icon icon="i-lucide-info" class="size-3.5" />
      {{ $t(`CHAT_LIST.NO_MESSAGES`) }}
    </span>

    <UnreadBadge
      :count="props.unreadCount"
      :align-bottom="props.showExpandedPreview"
    />
  </div>
</template>
