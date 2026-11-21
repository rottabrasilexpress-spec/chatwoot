<script setup>
import { useI18n } from 'vue-i18n';

const order = defineModel({ type: String, required: true });
const { t } = useI18n();

const toggle = () => {
  order.value = order.value === 'pickup_desc' ? 'pickup_asc' : 'pickup_desc';
};
</script>

<template>
  <button
    type="button"
    class="inline-flex min-h-8 shrink-0 items-center gap-1 rounded-lg border border-n-weak px-2 text-xs font-semibold text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
    :title="t('ROTTA_PICKUP.SORT_TOGGLE')"
    :aria-label="t('ROTTA_PICKUP.SORT_TOGGLE')"
    :aria-pressed="order === 'pickup_desc'"
    @click="toggle"
  >
    {{ t('ROTTA_PICKUP.COLLECTION_SHORT') }}
    <span aria-hidden="true">{{ order === 'pickup_desc' ? '↓' : '↑' }}</span>
  </button>
</template>
