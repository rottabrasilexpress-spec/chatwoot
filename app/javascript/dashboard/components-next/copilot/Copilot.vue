<script setup>
import { nextTick, ref, watch, computed } from 'vue';
import { useTrack } from 'dashboard/composables';
import { COPILOT_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import { useUISettings } from 'dashboard/composables/useUISettings';

import CopilotInput from './CopilotInput.vue';
import CopilotLoader from './CopilotLoader.vue';
import CopilotAgentMessage from './CopilotAgentMessage.vue';
import CopilotAssistantMessage from './CopilotAssistantMessage.vue';
import CopilotThinkingGroup from './CopilotThinkingGroup.vue';
import ToggleCopilotAssistant from './ToggleCopilotAssistant.vue';
import CopilotEmptyState from './CopilotEmptyState.vue';
import SidebarActionsHeader from 'dashboard/components-next/SidebarActionsHeader.vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  messages: {
    type: Array,
    default: () => [],
  },
  conversationInboxType: {
    type: String,
    required: true,
  },
  assistants: {
    type: Array,
    default: () => [],
  },
  activeAssistant: {
    type: Object,
    default: () => ({}),
  },
  canSuggestReply: {
    type: Boolean,
    default: true,
  },
  conversationAiMode: {
    type: Boolean,
    default: false,
  },
  responsePending: { type: Boolean, default: false },
  responseError: { type: String, default: '' },
  historyLoading: { type: Boolean, default: false },
  historyError: { type: Boolean, default: false },
  hasOlderHistory: { type: Boolean, default: false },
  conversationId: { type: [Number, String], default: null },
});

const emit = defineEmits([
  'sendMessage',
  'reset',
  'setAssistant',
  'refreshResponse',
  'loadOlderHistory',
  'retryHistory',
]);

const { t } = useI18n();
const deepMode = ref(false);
const shortcuts = [
  { mode: 'pending', icon: 'i-lucide-list-checks' },
  { mode: 'prequote', icon: 'i-lucide-clipboard-list' },
  { mode: 'pricing', icon: 'i-lucide-calculator' },
];
const shortcutsDisabled = computed(
  () => props.responsePending || props.historyLoading || props.historyError
);

const sendMessage = message => {
  emit(
    'sendMessage',
    props.conversationAiMode && deepMode.value
      ? { message, mode: 'deep' }
      : message
  );
  useTrack(COPILOT_EVENTS.SEND_MESSAGE);
};

const useShortcut = mode => {
  const key = `CONVERSATION.COPILOT.SHORTCUTS.${mode.toUpperCase()}`;
  emit('sendMessage', { message: t(`${key}.PROMPT`), mode });
  useTrack(COPILOT_EVENTS.SEND_MESSAGE);
};

watch(
  () => props.conversationId,
  () => {
    deepMode.value = false;
  }
);
const chatContainer = ref(null);

const scrollToBottom = async () => {
  await nextTick();
  if (chatContainer.value) {
    chatContainer.value.scrollTop = chatContainer.value.scrollHeight;
  }
};

const groupedMessages = computed(() => {
  const result = [];
  let thinkingGroup = [];
  props.messages.forEach(message => {
    if (message.message_type === 'assistant_thinking') {
      thinkingGroup.push(message);
    } else {
      if (thinkingGroup.length > 0) {
        result.push({
          id: thinkingGroup[0].id,
          message_type: 'thinking_group',
          messages: thinkingGroup,
        });
        thinkingGroup = [];
      }
      result.push(message);
    }
  });
  if (thinkingGroup.length > 0) {
    result.push({
      id: thinkingGroup[0].id,
      message_type: 'thinking_group',
      messages: thinkingGroup,
    });
  }
  return result;
});

const isLastMessageFromAssistant = computed(() => {
  if (groupedMessages.value.length === 0) return false;

  return (
    groupedMessages.value[groupedMessages.value.length - 1].message_type ===
    'assistant'
  );
});

const { updateUISettings } = useUISettings();

const closeCopilotPanel = () => {
  updateUISettings({
    is_copilot_panel_open: false,
    is_contact_sidebar_open: false,
    is_conversation_ai_open: false,
  });
};

const handleSidebarAction = action => {
  if (action === 'reset') {
    emit('reset');
  }
};

const hasAssistants = computed(() => props.assistants.length > 0);
const canUseConversationAiInput = computed(
  () => hasAssistants.value || props.conversationAiMode
);
const hasMessages = computed(() => props.messages.length > 0);
const copilotButtons = computed(() => {
  if (hasMessages.value && !props.conversationAiMode) {
    return [
      {
        key: 'reset',
        icon: 'i-lucide-refresh-ccw',
        tooltip: t('CAPTAIN.COPILOT.RESET'),
      },
    ];
  }
  return [];
});
watch(() => props.messages.at(-1)?.id, scrollToBottom);

const showOlderHistory = async () => {
  if (!chatContainer.value) return;
  const height = chatContainer.value.scrollHeight;
  const top = chatContainer.value.scrollTop;
  emit('loadOlderHistory');
  const stop = watch(
    () => props.historyLoading,
    async loading => {
      if (loading) return;
      stop();
      await nextTick();
      if (chatContainer.value)
        chatContainer.value.scrollTop =
          top + chatContainer.value.scrollHeight - height;
    }
  );
};
</script>

<template>
  <div class="flex flex-col h-full text-sm leading-6 tracking-tight w-full">
    <SidebarActionsHeader
      :title="
        conversationAiMode
          ? $t('CONVERSATION.COPILOT.CONVERSATION_AI_TITLE')
          : $t('CAPTAIN.COPILOT.TITLE')
      "
      :buttons="copilotButtons"
      @click="handleSidebarAction"
      @close="closeCopilotPanel"
    />
    <p
      v-if="conversationAiMode"
      class="px-4 py-2 text-xs leading-5 text-n-slate-10 border-b border-n-weak"
    >
      {{ $t('CONVERSATION.COPILOT.CONVERSATION_AI_DESCRIPTION') }}
    </p>
    <div
      v-if="conversationAiMode && conversationId"
      class="flex flex-wrap gap-2 px-4 py-3 border-b border-n-weak"
    >
      <button
        v-for="shortcut in shortcuts"
        :key="shortcut.mode"
        type="button"
        :disabled="shortcutsDisabled"
        class="inline-flex items-center gap-1.5 rounded-md border border-n-weak px-2.5 py-1.5 text-xs font-medium text-n-slate-12 hover:bg-n-alpha-2 disabled:opacity-50"
        @click="useShortcut(shortcut.mode)"
      >
        <i :class="shortcut.icon" aria-hidden="true" />
        {{
          t(
            `CONVERSATION.COPILOT.SHORTCUTS.${shortcut.mode.toUpperCase()}.LABEL`
          )
        }}
      </button>
    </div>
    <div
      ref="chatContainer"
      class="flex-1 flex px-4 py-4 overflow-y-auto items-start"
    >
      <div
        v-if="historyError"
        role="alert"
        class="flex flex-col items-start gap-2 text-n-slate-11"
      >
        {{ t('CONVERSATION.COPILOT.HISTORY_ERROR') }}
        <button
          type="button"
          class="text-n-blue-11 underline"
          @click="emit('retryHistory')"
        >
          {{ t('CONVERSATION.COPILOT.RETRY_HISTORY') }}
        </button>
      </div>
      <div
        v-else-if="hasMessages"
        class="space-y-6 flex-1 flex flex-col w-full min-w-0"
      >
        <button
          v-if="hasOlderHistory"
          type="button"
          class="self-center rounded-md border border-n-weak px-3 py-1.5 text-xs text-n-blue-11"
          :disabled="historyLoading"
          @click="showOlderHistory"
        >
          {{ t('CONVERSATION.COPILOT.OLDER_HISTORY') }}
        </button>
        <template v-for="(item, index) in groupedMessages" :key="item.id">
          <CopilotAgentMessage
            v-if="item.message_type === 'user'"
            :message="item.message"
          />
          <CopilotAssistantMessage
            v-else-if="item.message_type === 'assistant'"
            :message="item.message"
            :is-last-message="index === groupedMessages.length - 1"
            :conversation-inbox-type="conversationInboxType"
          />
          <CopilotThinkingGroup
            v-else
            :messages="item.messages"
            :default-collapsed="isLastMessageFromAssistant"
          />
        </template>

        <CopilotLoader
          v-if="
            conversationAiMode ? responsePending : !isLastMessageFromAssistant
          "
        />
        <div
          v-if="
            conversationAiMode && responseError && !isLastMessageFromAssistant
          "
          role="alert"
          class="rounded-lg border border-n-weak bg-n-alpha-2 p-3 text-n-slate-12"
        >
          <p>{{ responseError }}</p>
          <button
            type="button"
            data-conversation-ai-refresh
            class="mt-2 text-n-blue-11 underline"
            @click="emit('refreshResponse')"
          >
            {{ $t('CONVERSATION.COPILOT.CHECK_RESPONSE') }}
          </button>
        </div>
      </div>
      <CopilotLoader
        v-else-if="historyLoading || (conversationAiMode && responsePending)"
      />
      <p v-else-if="conversationAiMode" class="text-n-slate-11">
        {{ t('CONVERSATION.COPILOT.PERSONAL_EMPTY') }}
      </p>
      <CopilotEmptyState
        v-else
        :has-assistants="canUseConversationAiInput"
        :can-suggest-reply="canSuggestReply"
        @use-suggestion="sendMessage"
      />
    </div>

    <div class="mx-3 mt-px mb-2">
      <div class="flex items-center gap-2 justify-between w-full mb-1">
        <ToggleCopilotAssistant
          v-if="assistants.length > 1"
          :assistants="assistants"
          :active-assistant="activeAssistant"
          @set-assistant="$event => emit('setAssistant', $event)"
        />
        <div v-else />
        <button
          v-if="conversationAiMode"
          type="button"
          :aria-pressed="deepMode"
          :title="t('CONVERSATION.COPILOT.DEEP_HINT')"
          class="inline-flex items-center gap-1.5 rounded-md border border-n-weak px-2.5 py-1 text-xs font-medium"
          :class="
            deepMode
              ? 'bg-n-blue-3 text-n-blue-11'
              : 'text-n-slate-11 hover:bg-n-alpha-2'
          "
          @click="deepMode = !deepMode"
        >
          <i class="i-lucide-brain" aria-hidden="true" />
          {{ t('CONVERSATION.COPILOT.DEEP') }}
        </button>
      </div>
      <CopilotInput
        v-if="canUseConversationAiInput"
        :key="conversationAiMode ? conversationId : 'copilot'"
        class="mb-1 w-full"
        :disabled="conversationAiMode && (shortcutsDisabled || !conversationId)"
        :dictation-conversation-id="conversationAiMode ? conversationId : null"
        @send="sendMessage"
      />
    </div>
  </div>
</template>
