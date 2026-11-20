<script setup>
import { computed } from 'vue';
import { pickupDateLabel, splitPickupName } from 'dashboard/helper/rottaPickup';

const props = defineProps({
  name: { type: String, default: '' },
  suffix: { type: String, default: '' },
  schedule: { type: Object, default: null },
});

const pickupLabel = computed(
  () =>
    pickupDateLabel(props.schedule?.starts_on, props.schedule?.ends_on) ||
    props.suffix ||
    splitPickupName(props.name, '', true)[1]
);
const deliveryLabel = computed(() =>
  pickupDateLabel(props.schedule?.delivery_on)
);
</script>

<template>
  <div
    v-if="pickupLabel || deliveryLabel"
    class="flex min-w-0 flex-wrap items-center gap-x-1.5 gap-y-0.5 text-xs leading-snug"
    data-testid="conversation-move-dates"
  >
    <span
      v-if="pickupLabel"
      class="rounded bg-n-amber-3 px-1.5 py-0.5 font-semibold text-n-amber-11"
    >
      {{ $t('ROTTA_PICKUP.COLLECTION_SHORT') }} {{ pickupLabel }}
    </span>
    <span
      v-if="deliveryLabel"
      class="rounded bg-n-blue-3 px-1.5 py-0.5 font-semibold text-n-blue-11"
    >
      {{ $t('ROTTA_PICKUP.DELIVERY_SHORT') }} {{ deliveryLabel }}
    </span>
  </div>
  <template v-else />
</template>
