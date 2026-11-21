<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { pickupDateLabel, splitPickupName } from 'dashboard/helper/rottaPickup';

const props = defineProps({
  name: { type: String, default: '' },
  suffix: { type: String, default: '' },
  schedule: { type: Object, default: null },
});

const { t } = useI18n();
const pickupLabel = computed(
  () =>
    pickupDateLabel(props.schedule?.starts_on, props.schedule?.ends_on) ||
    props.suffix ||
    splitPickupName(props.name, '', true)[1]
);
const deliveryLabel = computed(() =>
  pickupDateLabel(props.schedule?.delivery_on)
);
const pickupText = computed(
  () =>
    t('ROTTA_PICKUP.COLLECTION_SHORT') +
    ' ' +
    (pickupLabel.value || t('ROTTA_PICKUP.PENDING'))
);
const deliveryText = computed(
  () =>
    t('ROTTA_PICKUP.DELIVERY_SHORT') +
    ' ' +
    (deliveryLabel.value || t('ROTTA_PICKUP.PENDING'))
);
</script>

<template>
  <div
    class="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 text-xs leading-snug"
    data-testid="conversation-move-dates"
  >
    <span
      class="inline-flex min-w-0 flex-wrap items-center gap-x-1.5 rounded-md bg-n-amber-3 px-2 py-1 font-semibold text-n-amber-11"
    >
      <span
        class="i-lucide-calendar-days size-3.5 shrink-0"
        aria-hidden="true"
      />
      <span>{{ pickupText }}</span>
    </span>
    <span
      class="inline-flex min-w-0 flex-wrap items-center gap-x-1.5 rounded-md px-2 py-1 font-semibold"
      :class="
        deliveryLabel
          ? 'bg-n-teal-3 text-n-teal-11'
          : 'bg-n-alpha-2 text-n-slate-11'
      "
    >
      <span class="i-lucide-truck size-3.5 shrink-0" aria-hidden="true" />
      <span>{{ deliveryText }}</span>
    </span>
  </div>
</template>
