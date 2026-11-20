<script setup>
import { computed } from 'vue';
import { splitPickupName } from 'dashboard/helper/rottaPickup';

const props = defineProps({
  name: { type: String, default: '' },
  suffix: { type: String, default: '' },
  allowLegacy: { type: Boolean, default: false },
});
const parts = computed(() =>
  splitPickupName(props.name, props.suffix, props.allowLegacy)
);
</script>

<template>
  <span
    ><span>{{ parts[0] }}</span
    ><template v-if="parts[1]">
      {{ ' ' }}<span class="font-semibold text-n-amber-11">{{ parts[1] }}</span>
    </template></span
  >
</template>
