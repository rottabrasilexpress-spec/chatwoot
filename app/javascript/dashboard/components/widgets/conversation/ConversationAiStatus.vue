<script setup>
import { computed, onMounted, onUnmounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  density: {
    type: String,
    default: 'header',
    validator: value => ['header', 'card', 'profile'].includes(value),
  },
});

const store = useStore();
const { t } = useI18n();
const record = computed(() =>
  store.getters['conversationAiStatus/getStatus'](props.conversationId)
);
const state = computed(() => record.value?.state || 'unknown');
const label = computed(() => {
  if (state.value === 'blocked') return t('CONVERSATION.AI_STATUS.OFF');
  if (state.value === 'active') return t('CONVERSATION.AI_STATUS.ON');
  return t('CONVERSATION.AI_STATUS.UNKNOWN_SHORT');
});
const description = computed(() => {
  if (state.value === 'blocked') return t('CONVERSATION.AI_STATUS.BLOCKED');
  if (state.value === 'active') return t('CONVERSATION.AI_STATUS.ACTIVE');
  return t('CONVERSATION.AI_STATUS.UNKNOWN');
});
const statusClass = computed(() => {
  if (state.value === 'blocked') {
    return 'border-n-ruby-4 bg-n-ruby-2 text-n-ruby-11';
  }
  if (state.value === 'active') {
    return 'border-n-teal-4 bg-n-teal-2 text-n-teal-11';
  }
  return 'border-n-slate-4 bg-n-slate-2 text-n-slate-10';
});
const densityClass = computed(() => {
  if (props.density === 'card') return 'h-4 px-1 text-[9px]';
  return 'h-5 px-1.5 text-[10px]';
});
const iconClass = computed(() =>
  props.density === 'card' ? 'size-2.5' : 'size-3'
);

const requestStatus = () => {
  store.dispatch('conversationAiStatus/ensure', props.conversationId);
};

let refreshInterval;
onMounted(() => {
  requestStatus();
  refreshInterval = setInterval(requestStatus, 20000);
});
onUnmounted(() => clearInterval(refreshInterval));
watch(() => props.conversationId, requestStatus);
</script>

<template>
  <span
    :data-ai-status="state"
    :aria-label="description"
    :title="description"
    class="relative inline-flex flex-shrink-0 items-center gap-0.5 rounded-full border font-semibold leading-none whitespace-nowrap"
    :class="[statusClass, densityClass]"
  >
    <Icon icon="i-lucide-bot" :class="iconClass" />
    <span
      v-if="state === 'blocked'"
      aria-hidden="true"
      class="absolute start-1 top-0 h-3 w-px rotate-45 bg-current"
    />
    <span>{{ label }}</span>
  </span>
</template>
