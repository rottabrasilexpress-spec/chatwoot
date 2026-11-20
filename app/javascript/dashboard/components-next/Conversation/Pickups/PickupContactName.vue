<script setup>
import { computed } from 'vue';
import { splitPickupName } from 'dashboard/helper/rottaPickup';

const props = defineProps({
  name: { type: String, default: '' },
  suffix: { type: String, default: '' },
  allowLegacy: { type: Boolean, default: false },
  showDate: { type: Boolean, default: true },
});
const parts = computed(() => {
  const [name, date] = splitPickupName(props.name, props.suffix);
  return date || !props.allowLegacy
    ? [name, date]
    : splitPickupName(props.name, '', true);
});
</script>

<template>
  <span>
    {{ parts[0] }}
    <span v-if="showDate && parts[1]" class="font-semibold text-n-amber-11">
      {{ parts[1] }}
    </span>
  </span>
</template>
