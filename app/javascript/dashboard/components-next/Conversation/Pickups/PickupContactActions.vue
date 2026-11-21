<script setup>
import { computed, ref, watch } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useStore } from 'dashboard/composables/store';
import {
  editPickupDates,
  pickupRevision,
} from 'dashboard/composables/useRottaPickupDialog';
import { isFlexiblePickup } from 'dashboard/helper/rottaPickup';
import api from 'dashboard/api/rottaPickups';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  schedule: { type: Object, default: null },
});

const store = useStore();
const legacyPickup = ref(null);
const pickup = computed(() => props.schedule || legacyPickup.value);

watch(
  [() => props.conversationId, () => props.schedule, pickupRevision],
  async ([id, schedule], _, onCleanup) => {
    if (schedule) return;
    let current = true;
    onCleanup(() => {
      current = false;
    });
    try {
      const { data } = await api.show(id);
      if (current) legacyPickup.value = data.pickup;
    } catch {
      // The editor can independently reload the latest schedule.
    }
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex w-full flex-wrap gap-1.5">
    <button
      v-if="isFlexiblePickup(pickup)"
      type="button"
      class="inline-flex min-h-8 items-center gap-1.5 rounded-lg bg-n-amber-3 px-2.5 text-xs font-medium text-n-amber-11 hover:bg-n-amber-4"
      @click="editPickupDates(conversationId, store, { confirmWindow: true })"
    >
      <Icon icon="i-lucide-calendar-check" class="size-3.5" />
      {{ $t('ROTTA_PICKUP.CONFIRM_DATE') }}
    </button>
    <button
      type="button"
      class="inline-flex min-h-8 items-center gap-1.5 rounded-lg border border-n-weak px-2.5 text-xs font-medium text-n-slate-11 hover:bg-n-alpha-2"
      @click="editPickupDates(conversationId, store)"
    >
      <Icon icon="i-lucide-calendar-pen" class="size-3.5" />
      {{ $t('ROTTA_PICKUP.EDIT_DATES') }}
    </button>
  </div>
</template>
