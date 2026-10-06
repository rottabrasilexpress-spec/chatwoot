<script setup>
import { computed, watch, onMounted, onUnmounted } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { useConversationFollowing } from 'dashboard/composables/useConversationFollowing';
import { useAlert } from 'dashboard/composables';
const props = defineProps({ conversationId: { type: Number, required: true } });
const copy = {
  retry: 'Tentar novamente',
  saving: 'Salvando…',
  active: 'Acompanhando',
  inactive: 'Acompanhar cliente',
};
const { session, status, setFollowing } = useConversationFollowing();
const active = computed(
  () => session.value.flags[props.conversationId] === true
);
const known = computed(
  () => typeof session.value.flags[props.conversationId] === 'boolean'
);
watch(
  () => [props.conversationId, session.value],
  () => status(props.conversationId),
  { immediate: true }
);
const toggle = async () => {
  const next = !active.value;
  if (await setFollowing(props.conversationId, next))
    useAlert(
      next
        ? 'Cliente adicionado ao acompanhamento da equipe. Veja em Retomar revisão.'
        : 'Cliente retirado do acompanhamento da equipe.'
    );
  else useAlert(session.value.error);
};
const revalidate = () => {
  if (document.visibilityState === 'visible') status(props.conversationId);
};
onMounted(() => {
  window.addEventListener('focus', revalidate);
  document.addEventListener('visibilitychange', revalidate);
  emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT, revalidate);
});
onUnmounted(() => {
  window.removeEventListener('focus', revalidate);
  document.removeEventListener('visibilitychange', revalidate);
  emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT, revalidate);
});
</script>

<template>
  <button
    type="button"
    :aria-pressed="active"
    :disabled="!known || session.busy[conversationId]"
    :title="
      active
        ? 'Retirar do acompanhamento da equipe'
        : 'Acompanhar este cliente com a equipe'
    "
    class="inline-flex shrink-0 items-center gap-1.5 rounded-lg px-2 py-2 text-xs font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand disabled:opacity-50"
    :class="
      active
        ? 'bg-n-teal-3 text-n-teal-11 hover:bg-n-teal-4'
        : 'text-n-slate-11 hover:bg-n-alpha-2'
    "
    @click="toggle"
  >
    <span
      class="size-4"
      :class="active ? 'i-lucide-eye' : 'i-lucide-eye-off'"
      aria-hidden="true"
    />
    {{
      session.busy[conversationId]
        ? copy.saving
        : active
          ? copy.active
          : copy.inactive
    }}
  </button>
  <button
    v-if="!known && session.error"
    type="button"
    class="text-xs text-n-ruby-11 underline px-2 py-2"
    @click="status(conversationId)"
  >
    {{ copy.retry }}
  </button>
</template>
