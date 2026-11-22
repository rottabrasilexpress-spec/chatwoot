/* global axios */
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

export default function useConversationAiBrief({
  accountId,
  conversationId,
  chat,
  user,
  lastPublicMessage,
  openPanel,
}) {
  const brief = ref(null);
  const openedVersions = new Map();
  let request = 0;

  const scope = computed(() => {
    const config = window.chatwootConfig || {};
    if (
      !user.value?.id ||
      !conversationId.value ||
      Number(config.rottaAttentionRequesterUserId) !== Number(user.value.id) ||
      Number(config.rottaConversationAiBriefAccountId) !==
        Number(accountId.value) ||
      Number(chat.value?.display_id ?? chat.value?.id) !==
        Number(conversationId.value)
    )
      return null;

    const labels = (chat.value.labels ?? [])
      .map(label =>
        label
          .toLowerCase()
          .normalize('NFD')
          .replace(/\p{Diacritic}/gu, '')
          .replace(/[^a-z0-9]+/g, '-')
      )
      .filter(label => ['kelvin', 'caio-atencao'].includes(label))
      .sort();

    return labels.length
      ? `${accountId.value}:${conversationId.value}:${labels.join(',')}`
      : null;
  });

  const refresh = async () => {
    request += 1;
    const revision = request;
    const key = scope.value;
    if (!key) return;

    try {
      const { data, status } = await axios.get(
        `/api/v1/accounts/${accountId.value}/captain/conversation_ai/automatic_brief`,
        { params: { conversation_id: conversationId.value } }
      );
      if (revision !== request || key !== scope.value) return;

      brief.value = status === 200 ? data : null;
      if (
        brief.value?.state === 'ready' &&
        openedVersions.get(key) !== data.version
      ) {
        openedVersions.set(key, data.version);
        openPanel();
      }
    } catch {
      if (revision === request && key === scope.value) brief.value = null;
    }
  };

  watch(
    scope,
    () => {
      brief.value = null;
      refresh();
    },
    { immediate: true }
  );
  watch(() => lastPublicMessage.value?.id, refresh);

  const onUpdated = event => {
    if (
      Number(event.account_id) === Number(accountId.value) &&
      Number(event.conversation_id) === Number(conversationId.value)
    )
      refresh();
  };

  onMounted(() => {
    emitter.on(BUS_EVENTS.CONVERSATION_AI_BRIEF_UPDATED, onUpdated);
    emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED, refresh);
  });
  onBeforeUnmount(() => {
    request += 1;
    emitter.off(BUS_EVENTS.CONVERSATION_AI_BRIEF_UPDATED, onUpdated);
    emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED, refresh);
  });

  return { brief };
}
