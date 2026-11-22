<script setup>
import { computed } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { useTrack } from 'dashboard/composables';

import { BUS_EVENTS } from 'shared/constants/busEvents';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import { COPILOT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  isLastMessage: {
    type: Boolean,
    default: false,
  },
  message: {
    type: Object,
    required: true,
  },
  conversationInboxType: {
    type: String,
    required: true,
  },
});
const hasEmptyMessageContent = computed(() => !props.message?.content);
const suggestedReply = computed(() => props.message?.suggested_reply);

const showUseButton = computed(() => {
  return (
    !hasEmptyMessageContent.value &&
    (suggestedReply.value ||
      (props.message.reply_suggestion && props.isLastMessage))
  );
});

const messageContent = computed(() => {
  const formatter = new MessageFormatter(props.message.content);
  return formatter.formattedMessage;
});

const insertIntoRichEditor = computed(() => {
  return [INBOX_TYPES.WEB, INBOX_TYPES.EMAIL].includes(
    props.conversationInboxType
  );
});

const useCopilotResponse = () => {
  const draft = suggestedReply.value || props.message.content;
  if (insertIntoRichEditor.value) {
    emitter.emit(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, draft);
  } else {
    emitter.emit(BUS_EVENTS.INSERT_INTO_NORMAL_EDITOR, draft);
  }
  useTrack(COPILOT_EVENTS.USE_CAPTAIN_RESPONSE);
};
</script>

<template>
  <div class="flex flex-col gap-1 text-n-slate-12">
    <div class="font-medium">{{ message.assistant || $t('CAPTAIN.NAME') }}</div>
    <span v-if="hasEmptyMessageContent" class="text-n-ruby-11">
      {{ $t('CAPTAIN.COPILOT.EMPTY_MESSAGE') }}
    </span>
    <div
      v-else
      v-dompurify-html="messageContent"
      class="prose-sm break-words"
    />
    <div
      v-if="suggestedReply"
      class="mt-1 rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-11"
    >
      <div class="mb-1 text-xs font-medium">
        {{ $t('CONVERSATION.COPILOT.SUGGESTED_REPLY') }}
      </div>
      <p class="m-0 whitespace-pre-wrap break-words">{{ suggestedReply }}</p>
    </div>
    <div class="flex flex-row mt-1">
      <Button
        v-if="showUseButton"
        :label="
          suggestedReply
            ? $t('CONVERSATION.COPILOT.USE_DRAFT')
            : $t('CAPTAIN.COPILOT.USE')
        "
        faded
        sm
        slate
        @click="useCopilotResponse"
      />
    </div>
  </div>
</template>
