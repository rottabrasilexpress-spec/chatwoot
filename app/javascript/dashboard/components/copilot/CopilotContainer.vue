<script setup>
import {
  ref,
  reactive,
  computed,
  onMounted,
  onBeforeUnmount,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import Copilot from 'dashboard/components-next/copilot/Copilot.vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useConfig } from 'dashboard/composables/useConfig';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import wootConstants from 'dashboard/constants/globals';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import CopilotThreadsAPI from 'dashboard/api/captain/copilotThreads';
import useConversationAiBrief from 'dashboard/composables/useConversationAiBrief';
import ConversationAiBrief from 'dashboard/components-next/copilot/ConversationAiBrief.vue';

defineProps({
  conversationInboxType: {
    type: String,
    default: '',
  },
});

const store = useStore();
const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();
const { isEnterprise } = useConfig();
const { width: windowWidth } = useWindowSize();

const currentUser = useMapGetter('getCurrentUser');
const assistants = useMapGetter('captainAssistants/getRecords');
const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const inboxAssistant = useMapGetter('getCopilotAssistant');
const currentChat = useMapGetter('getSelectedChat');
const lastPublicMessage = useMapGetter('getLastEmailInSelectedChat');

const currentConversationId = computed(() => {
  const routeMatch = window.location.pathname.match(/\/conversations\/(\d+)/);
  const conversation = currentChat.value;
  return routeMatch
    ? Number(routeMatch[1])
    : (conversation?.display_id ?? conversation?.id ?? null);
});

const isConversationAiMode = computed(
  () => uiSettings.value?.is_conversation_ai_open === true
);

const canSuggestReply = computed(
  () => lastPublicMessage.value?.message_type === MESSAGE_TYPE.INCOMING
);

const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const selectedCopilotThreadId = ref(null);
const conversationAiRefreshPromises = new Map();
const conversationAiRequests = reactive(new Map());
const historyLoading = ref(false);
const historyError = ref(false);
const hasOlderHistory = ref(false);
const panelWidth = ref(360);
let historyRevision = 0;
let dragStart;
const isSending = ref(false);
let disposed = false;
const responsePending = computed(
  () =>
    isSending.value ||
    conversationAiRequests.get(selectedCopilotThreadId.value)?.pending === true
);
const responseError = computed(
  () => conversationAiRequests.get(selectedCopilotThreadId.value)?.error || ''
);

const getMessagesForThread = threadId =>
  store.getters['copilotMessages/getMessagesByThreadId'](threadId);

const normalizeAssistantMessage = message => {
  if (message?.message_type !== 'assistant') return message;

  const content =
    typeof message.message === 'string'
      ? message.message
      : message.message?.content;
  if (!content) return message;

  const normalizedContent = content
    .split('Nenhuna')
    .join('Nenhuma')
    .split('nenhuna')
    .join('nenhuma')
    .split('cree-a')
    .join('crie-a');
  if (normalizedContent === content) return message;

  return {
    ...message,
    message:
      typeof message.message === 'string'
        ? normalizedContent
        : { ...message.message, content: normalizedContent },
  };
};

const messages = computed(() =>
  getMessagesForThread(selectedCopilotThreadId.value).map(
    normalizeAssistantMessage
  )
);

const currentAccountId = useMapGetter('getCurrentAccountId');
const { brief } = useConversationAiBrief({
  accountId: currentAccountId,
  conversationId: currentConversationId,
  chat: currentChat,
  user: currentUser,
  lastPublicMessage,
  openPanel: () => {
    if (uiSettings.value?.is_conversation_ai_open) return;
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: true,
      is_conversation_ai_open: true,
    });
  },
});
const isFeatureEnabledonAccount = useMapGetter(
  'accounts/isFeatureEnabledonAccount'
);

const captainTasksEnabled = computed(() =>
  isFeatureEnabledonAccount.value(
    currentAccountId.value,
    FEATURE_FLAGS.CAPTAIN_TASKS
  )
);

const selectedAssistantId = ref(null);

const activeAssistant = computed(() => {
  const preferredId = uiSettings.value.preferred_captain_assistant_id;

  // If the user has selected a specific assistant, it takes first preference for Copilot.
  if (preferredId) {
    const preferredAssistant = assistants.value.find(a => a.id === preferredId);
    // Return the preferred assistant if found, otherwise continue to next cases
    if (preferredAssistant) return preferredAssistant;
  }

  // If the above is not available, the assistant connected to the inbox takes preference.
  if (inboxAssistant.value) {
    const inboxMatchedAssistant = assistants.value.find(
      a => a.id === inboxAssistant.value.id
    );
    if (inboxMatchedAssistant) return inboxMatchedAssistant;
  }
  // If neither of the above is available, the first assistant in the account takes preference.
  return assistants.value[0];
});

const closeCopilotPanel = () => {
  if (isSmallScreen.value && uiSettings.value?.is_copilot_panel_open) {
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
      is_conversation_ai_open: false,
    });
  }
};

const setAssistant = async assistant => {
  selectedAssistantId.value = assistant.id;
  await updateUISettings({
    preferred_captain_assistant_id: assistant.id,
  });
};

const shouldShowCopilotPanel = computed(() => {
  const isCaptainEnabled = isFeatureEnabledonAccount.value(
    currentAccountId.value,
    FEATURE_FLAGS.CAPTAIN
  );
  const { is_copilot_panel_open: isCopilotPanelOpen } = uiSettings.value;
  const canUseCopilotPanel =
    isEnterprise || isCaptainEnabled || captainTasksEnabled.value;
  return (
    canUseCopilotPanel && isCopilotPanelOpen && !uiFlags.value.fetchingList
  );
});

const handleReset = () => {
  selectedCopilotThreadId.value = null;
};

const maxPanelWidth = computed(() =>
  Math.max(320, Math.min(720, windowWidth.value - 430))
);
const resize = width => {
  panelWidth.value = Math.min(maxPanelWidth.value, Math.max(320, width));
};
watch(maxPanelWidth, () => resize(panelWidth.value));

const startResize = event => {
  if (event.button !== 0) return;
  dragStart = { x: event.clientX, width: panelWidth.value };
  event.currentTarget.setPointerCapture(event.pointerId);
};

const resizeOnMove = event => {
  if (dragStart) resize(dragStart.width + dragStart.x - event.clientX);
};

const finishResize = () => {
  dragStart = undefined;
};

const wait = timeout =>
  new Promise(resolve => {
    setTimeout(resolve, timeout);
  });

const CONVERSATION_AI_POLL_INTERVAL = 4000;
const CONVERSATION_AI_MAX_POLL_ATTEMPTS = 45;

const refreshConversationAiMessages = async (
  threadId,
  assistantCountBeforeRequest,
  requestMessage,
  requestMessageId,
  conversationId = currentConversationId.value
) => {
  const promiseKey = `${threadId}:${requestMessageId || requestMessage}`;
  const existingPromise = conversationAiRefreshPromises.get(promiseKey);
  if (existingPromise) return existingPromise;

  const request = reactive({
    pending: true,
    error: '',
    assistantCountBeforeRequest,
    requestMessage,
    requestMessageId,
    conversationId,
  });
  conversationAiRequests.set(threadId, request);
  const hasAnswer = () => {
    const replies = getMessagesForThread(threadId).filter(
      message => message.message_type === 'assistant'
    );
    if (!requestMessageId) return replies.length > assistantCountBeforeRequest;
    return replies.some(message =>
      message.message?.in_reply_to
        ? Number(message.message.in_reply_to) === Number(requestMessageId)
        : Number(message.id) > Number(requestMessageId)
    );
  };

  const refreshPromise = (async () => {
    const deadline = Date.now() + 180000;
    for (
      let attempt = 0;
      !disposed &&
      attempt < CONVERSATION_AI_MAX_POLL_ATTEMPTS &&
      Date.now() < deadline;
      attempt += 1
    ) {
      // This bounded polling is the fallback when ActionCable is disconnected.
      if (!hasAnswer())
        try {
          // eslint-disable-next-line no-await-in-loop
          await store.dispatch(
            'copilotMessages/get',
            requestMessageId
              ? { threadId, afterId: requestMessageId }
              : threadId
          );
        } catch (error) {
          // A transient fetch failure must not strand an otherwise running answer.
        }
      if (hasAnswer()) {
        if (
          isConversationAiMode.value &&
          currentConversationId.value === conversationId
        ) {
          store.dispatch('getConversation', conversationId).catch(() => {});
        }
        return;
      }
      if (attempt < CONVERSATION_AI_MAX_POLL_ATTEMPTS - 1) {
        // eslint-disable-next-line no-await-in-loop
        await wait(CONVERSATION_AI_POLL_INTERVAL);
      }
    }
    if (!disposed) request.error = t('CONVERSATION.COPILOT.RESPONSE_DELAYED');
  })();

  conversationAiRefreshPromises.set(promiseKey, refreshPromise);
  refreshPromise.finally(() => {
    request.pending = false;
    if (conversationAiRefreshPromises.get(promiseKey) === refreshPromise) {
      conversationAiRefreshPromises.delete(promiseKey);
    }
  });

  return refreshPromise;
};

const refreshResponse = () => {
  const threadId = selectedCopilotThreadId.value;
  const request = conversationAiRequests.get(threadId);
  if (!request) return;
  refreshConversationAiMessages(
    threadId,
    request.assistantCountBeforeRequest,
    request.requestMessage,
    request.requestMessageId,
    request.conversationId
  );
};

const openHistory = async () => {
  historyRevision += 1;
  const revision = historyRevision;
  handleReset();
  hasOlderHistory.value = false;
  historyError.value = false;
  historyLoading.value = false;
  const conversationId = currentConversationId.value;
  if (
    !isConversationAiMode.value ||
    !shouldShowCopilotPanel.value ||
    !conversationId
  )
    return;

  historyLoading.value = true;
  try {
    const { data } = await CopilotThreadsAPI.get({
      conversation_id: conversationId,
      request_type: 'conversation_ai',
    });
    const threadId = data.payload?.[0]?.id;
    if (disposed || revision !== historyRevision || !threadId) return;
    const records = await store.dispatch('copilotMessages/get', threadId);
    if (disposed || revision !== historyRevision) return;
    selectedCopilotThreadId.value = threadId;
    hasOlderHistory.value = records?.length === 40;
    const current = getMessagesForThread(threadId);
    const last = current.at(-1);
    if (
      last?.message_type === 'user' &&
      !conversationAiRequests.has(threadId) &&
      Date.now() - Number(last.created_at) * 1000 < 180000
    ) {
      refreshConversationAiMessages(
        threadId,
        0,
        last.message?.content,
        last.id,
        conversationId
      );
    }
  } catch {
    if (revision === historyRevision) historyError.value = true;
  } finally {
    if (revision === historyRevision) historyLoading.value = false;
  }
};

const loadOlderHistory = async () => {
  const threadId = selectedCopilotThreadId.value;
  const beforeId = getMessagesForThread(threadId)[0]?.id;
  if (!beforeId || historyLoading.value) return;
  historyLoading.value = true;
  try {
    const records = await store.dispatch('copilotMessages/get', {
      threadId,
      beforeId,
    });
    if (threadId === selectedCopilotThreadId.value)
      hasOlderHistory.value = records?.length === 40;
  } catch {
    useAlert(t('CONVERSATION.COPILOT.HISTORY_ERROR'));
  } finally {
    if (threadId === selectedCopilotThreadId.value)
      historyLoading.value = false;
  }
};

watch(
  [
    currentAccountId,
    currentConversationId,
    isConversationAiMode,
    shouldShowCopilotPanel,
  ],
  openHistory,
  {
    immediate: true,
  }
);

onBeforeUnmount(() => {
  disposed = true;
});

const sendMessage = async payload => {
  if (
    isConversationAiMode.value &&
    (responsePending.value || historyLoading.value || historyError.value)
  )
    return;
  isSending.value = true;
  const message = typeof payload === 'string' ? payload : payload.message;
  const requestType =
    typeof payload === 'string' ? undefined : payload.requestType;
  const mode = typeof payload === 'string' ? undefined : payload.mode;
  const conversationMode = isConversationAiMode.value;
  const assistantId = activeAssistant.value?.id;
  const conversationId = currentConversationId.value;
  const threadId = selectedCopilotThreadId.value;
  const revision = historyRevision;
  const assistantCountBeforeRequest = messages.value.filter(
    item => item.message_type === 'assistant'
  ).length;

  try {
    if (threadId) {
      const response = await store.dispatch('copilotMessages/create', {
        ...(assistantId && { assistant_id: assistantId }),
        conversation_id: conversationId,
        threadId,
        message,
        ...(conversationMode && mode && { mode }),
      });
      if (conversationMode) {
        refreshConversationAiMessages(
          threadId,
          assistantCountBeforeRequest,
          message,
          response?.id,
          conversationId
        );
      }
    } else {
      const response = await store.dispatch('copilotThreads/create', {
        ...(assistantId && { assistant_id: assistantId }),
        conversation_id: conversationId,
        message,
        ...(conversationMode
          ? { request_type: 'conversation_ai', ...(mode && { mode }) }
          : requestType && { request_type: requestType }),
      });
      if (revision === historyRevision) {
        selectedCopilotThreadId.value = response.id;
      }
      if (conversationMode) {
        refreshConversationAiMessages(
          response.id,
          assistantCountBeforeRequest,
          message,
          response.copilot_message_id,
          conversationId
        );
      }
    }
  } catch (error) {
    useAlert(error.message);
  } finally {
    isSending.value = false;
  }
};

onMounted(() => {
  if (isEnterprise || captainTasksEnabled.value) {
    store.dispatch('captainAssistants/get');
  }
});
</script>

<template>
  <div
    v-if="shouldShowCopilotPanel"
    v-on-click-outside="[
      closeCopilotPanel,
      { ignore: ['[data-conversation-ai-toggle]'] },
    ]"
    class="bg-n-surface-2 h-full overflow-hidden flex flex-col fixed top-0 ltr:right-0 rtl:left-0 z-40 w-full max-w-sm md:relative ltr:border-l rtl:border-r border-n-weak shadow-lg md:shadow-none"
    :style="
      isConversationAiMode
        ? { '--conversation-ai-width': `${panelWidth}px` }
        : undefined
    "
    :class="[
      {
        'md:flex': shouldShowCopilotPanel,
        'md:hidden': !shouldShowCopilotPanel,
        'md:w-[var(--conversation-ai-width)] md:max-w-none md:shrink-0':
          isConversationAiMode,
        'md:w-[320px] md:min-w-[320px] 2xl:min-w-[360px] 2xl:w-[360px]':
          !isConversationAiMode,
      },
    ]"
  >
    <div
      v-if="isConversationAiMode"
      role="separator"
      tabindex="0"
      aria-orientation="vertical"
      :aria-label="t('CONVERSATION.COPILOT.RESIZE')"
      :aria-valuemin="320"
      :aria-valuemax="maxPanelWidth"
      :aria-valuenow="panelWidth"
      class="absolute inset-y-0 left-0 z-10 hidden w-2 touch-none cursor-col-resize border-l-2 border-transparent hover:border-n-blue-9 focus-visible:border-n-blue-9 md:block"
      @pointerdown="startResize"
      @pointermove="resizeOnMove"
      @lostpointercapture="finishResize"
      @keydown.left.prevent="resize(panelWidth + 24)"
      @keydown.right.prevent="resize(panelWidth - 24)"
    />
    <Copilot
      :messages="messages"
      :support-agent="currentUser"
      :conversation-inbox-type="conversationInboxType"
      :assistants="assistants"
      :active-assistant="activeAssistant"
      :can-suggest-reply="canSuggestReply"
      :conversation-ai-mode="isConversationAiMode"
      :response-pending="responsePending"
      :response-error="responseError"
      :conversation-id="currentConversationId"
      :history-loading="historyLoading"
      :history-error="historyError"
      :has-older-history="hasOlderHistory"
      @set-assistant="setAssistant"
      @send-message="sendMessage"
      @reset="handleReset"
      @refresh-response="refreshResponse"
      @retry-history="openHistory"
      @load-older-history="loadOlderHistory"
    >
      <template v-if="isConversationAiMode && brief" #automatic-brief>
        <ConversationAiBrief
          :brief="brief"
          :conversation-id="currentConversationId"
        />
      </template>
    </Copilot>
  </div>
  <template v-else />
</template>
