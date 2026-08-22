<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import wootConstants from 'dashboard/constants/globals';

import Banner from 'dashboard/components/ui/Banner.vue';

const store = useStore();
const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');

const isPendingConversation = computed(
  () => currentChat.value?.status === wootConstants.STATUS_TYPE.PENDING
);

const isAgentBotOwned = computed(
  () => currentChat.value?.meta?.assignee_type === 'AgentBot'
);

const showBotHandoffBanner = computed(() => {
  return isPendingConversation.value && isAgentBotOwned.value;
});

const botAssigneeName = computed(() => {
  return t('CONVERSATION.BOT_HANDOFF_FALLBACK_ASSIGNEE');
});

const reopenConversation = async () => {
  await store.dispatch('toggleStatus', {
    conversationId: currentChat.value?.id,
    status: 'open',
  });
};

const onClickBotHandoff = async () => {
  try {
    await reopenConversation();
    // Reopen for the shared team and clear the bot owner without assigning a
    // human agent. Every agent must see the same conversation pool.
    await store.dispatch('assignAgent', {
      conversationId: currentChat.value?.id,
      agentId: null,
    });

    useAlert(t('CONVERSATION.BOT_HANDOFF_SUCCESS'));
  } catch (error) {
    useAlert(t('CONVERSATION.BOT_HANDOFF_ERROR'));
  }
};
</script>

<template>
  <div class="contents">
    <Banner
      v-if="showBotHandoffBanner"
      action-button-variant="ghost"
      color-scheme="secondary"
      class="mx-2 mb-2 rounded-lg !py-2"
      :banner-message="
        $t('CONVERSATION.BOT_HANDOFF_MESSAGE', {
          assigneeName: botAssigneeName,
        })
      "
      has-action-button
      :action-button-label="$t('CONVERSATION.BOT_HANDOFF_ACTION')"
      @primary-action="onClickBotHandoff"
    />
  </div>
</template>
