<script setup>
import { ref, computed, onMounted, watch } from 'vue';
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

defineProps({
  conversationInboxType: {
    type: String,
    default: '',
  },
});

const store = useStore();
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
  const conversation = currentChat.value;
  if (conversation?.display_id) return conversation.display_id;

  const routeMatch = window.location.pathname.match(/\/conversations\/(\d+)/);
  if (routeMatch?.[1]) return routeMatch[1];

  if (conversation?.id) return conversation.id;
  return null;
});

const canSuggestReply = computed(
  () => lastPublicMessage.value?.message_type === MESSAGE_TYPE.INCOMING
);

const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const selectedCopilotThreadId = ref(null);
const conversationAiRefreshPromises = new Map();
const messages = computed(() =>
  store.getters['copilotMessages/getMessagesByThreadId'](
    selectedCopilotThreadId.value
  )
);

const currentAccountId = useMapGetter('getCurrentAccountId');
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

const isConversationAiMode = computed(
  () => uiSettings.value?.is_conversation_ai_open === true
);

const handleReset = async () => {
  selectedCopilotThreadId.value = null;

  const conversationId = currentConversationId.value;
  if (!isConversationAiMode.value || !conversationId) return;

  try {
    const threads = await store.dispatch('copilotThreads/get', {
      conversation_id: conversationId,
      ...(isConversationAiMode.value && { request_type: 'conversation_ai' }),
    });
    const thread = threads?.[0];
    if (!thread || currentConversationId.value !== conversationId) return;

    selectedCopilotThreadId.value = thread.id;
    await store.dispatch('copilotMessages/get', thread.id);
  } catch (error) {
    useAlert(error.message);
  }
};

watch([currentConversationId, isConversationAiMode], handleReset);

const wait = timeout =>
  new Promise(resolve => {
    setTimeout(resolve, timeout);
  });

const CONVERSATION_AI_POLL_INTERVAL = 2000;
const CONVERSATION_AI_MAX_POLL_ATTEMPTS = 90;

const refreshConversationAiMessages = async (
  threadId,
  assistantCountBeforeRequest
) => {
  const existingPromise = conversationAiRefreshPromises.get(threadId);
  if (existingPromise) return existingPromise;

  const refreshPromise = (async () => {
    for (
      let attempt = 0;
      attempt < CONVERSATION_AI_MAX_POLL_ATTEMPTS;
      attempt += 1
    ) {
      // This bounded polling is the fallback when ActionCable is disconnected.
      try {
        // eslint-disable-next-line no-await-in-loop
        await store.dispatch('copilotMessages/get', threadId);
      } catch (error) {
        useAlert(error.message);
        return;
      }
      const assistantCount = store.getters[
        'copilotMessages/getMessagesByThreadId'
      ](threadId).filter(
        message => message.message_type === 'assistant'
      ).length;

      if (assistantCount > assistantCountBeforeRequest) return;
      if (attempt < CONVERSATION_AI_MAX_POLL_ATTEMPTS - 1) {
        // eslint-disable-next-line no-await-in-loop
        await wait(CONVERSATION_AI_POLL_INTERVAL);
      }
    }
  })();

  conversationAiRefreshPromises.set(threadId, refreshPromise);
  refreshPromise.finally(() => {
    if (conversationAiRefreshPromises.get(threadId) === refreshPromise) {
      conversationAiRefreshPromises.delete(threadId);
    }
  });

  return refreshPromise;
};

const sendMessage = async payload => {
  const message = typeof payload === 'string' ? payload : payload.message;
  const requestType =
    typeof payload === 'string' ? undefined : payload.requestType;
  const assistantId = activeAssistant.value?.id;
  const assistantCountBeforeRequest = messages.value.filter(
    item => item.message_type === 'assistant'
  ).length;

  try {
    if (selectedCopilotThreadId.value) {
      await store.dispatch('copilotMessages/create', {
        ...(assistantId && { assistant_id: assistantId }),
        conversation_id: currentConversationId.value,
        threadId: selectedCopilotThreadId.value,
        message,
      });
      if (isConversationAiMode.value) {
        refreshConversationAiMessages(
          selectedCopilotThreadId.value,
          assistantCountBeforeRequest
        );
      }
    } else {
      const conversationId = currentConversationId.value;
      const response = await store.dispatch('copilotThreads/create', {
        ...(assistantId && { assistant_id: assistantId }),
        conversation_id: conversationId,
        message,
        ...(isConversationAiMode.value && { request_type: 'conversation_ai' }),
        ...(requestType && { request_type: requestType }),
      });
      if (currentConversationId.value === conversationId) {
        selectedCopilotThreadId.value = response.id;
        if (isConversationAiMode.value) {
          await store.dispatch('copilotMessages/get', response.id);
          refreshConversationAiMessages(
            response.id,
            assistantCountBeforeRequest
          );
        }
      }
    }
  } catch (error) {
    useAlert(error.message);
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
    class="bg-n-surface-2 h-full overflow-hidden flex-col fixed top-0 ltr:right-0 rtl:left-0 z-40 w-full max-w-sm transition-transform duration-300 ease-in-out md:static md:w-[320px] md:min-w-[320px] ltr:border-l rtl:border-r border-n-weak 2xl:min-w-[360px] 2xl:w-[360px] shadow-lg md:shadow-none"
    :class="[
      {
        'md:flex': shouldShowCopilotPanel,
        'md:hidden': !shouldShowCopilotPanel,
      },
    ]"
  >
    <Copilot
      :messages="messages"
      :support-agent="currentUser"
      :conversation-inbox-type="conversationInboxType"
      :assistants="assistants"
      :active-assistant="activeAssistant"
      :can-suggest-reply="canSuggestReply"
      :conversation-ai-mode="isConversationAiMode"
      @set-assistant="setAssistant"
      @send-message="sendMessage"
      @reset="handleReset"
    />
  </div>
  <template v-else />
</template>
