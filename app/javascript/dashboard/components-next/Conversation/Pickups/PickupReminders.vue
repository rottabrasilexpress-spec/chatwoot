<script setup>
import { useI18n } from 'vue-i18n';
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import api from 'dashboard/api/rottaPickups';
import {
  pickupRequest,
  pickupRevision,
} from 'dashboard/composables/useRottaPickupDialog';
import PickupContactName from './PickupContactName.vue';

const { t } = useI18n();

const route = useRoute();
const dialog = ref(null);
const reminders = ref([]);
const date = ref('');
const acknowledging = ref(false);
const error = ref(false);
const accountId = computed(() => route.params.accountId);
let inFlight = false;
let timer;

const readReminders = async () => {
  if (document.hidden || inFlight || acknowledging.value || !accountId.value)
    return;
  inFlight = true;
  const account = accountId.value;
  try {
    const { data } = await api.reminders();
    if (account !== accountId.value) return;
    date.value = data.day;
    reminders.value = data.items;
  } catch {
    // The next visible poll retries; keep the alert already on screen.
  } finally {
    inFlight = false;
  }
};

watch(
  [reminders, pickupRequest],
  () => {
    if (reminders.value.length && !pickupRequest.value && !dialog.value?.open) {
      dialog.value?.showModal();
    } else if (!reminders.value.length || pickupRequest.value) {
      dialog.value?.close();
    }
  },
  { flush: 'post' }
);

watch(accountId, () => {
  reminders.value = [];
  readReminders();
});

watch(pickupRevision, readReminders);
onMounted(() => {
  readReminders();
  document.addEventListener('visibilitychange', readReminders);
  window.addEventListener('focus', readReminders);
  timer = window.setInterval(readReminders, 120000);
});

onUnmounted(() => {
  document.removeEventListener('visibilitychange', readReminders);
  window.removeEventListener('focus', readReminders);
  window.clearInterval(timer);
});

const acknowledge = async () => {
  if (acknowledging.value) return;
  acknowledging.value = true;
  error.value = false;
  try {
    await api.acknowledge(date.value, reminders.value);
    reminders.value = [];
  } catch {
    error.value = true;
  } finally {
    acknowledging.value = false;
  }
};

const timing = days =>
  [
    t('ROTTA_PICKUP.TODAY'),
    t('ROTTA_PICKUP.ONE_DAY'),
    t('ROTTA_PICKUP.TWO_DAYS'),
  ][days];
</script>

<template>
  <Teleport to="body">
    <dialog
      ref="dialog"
      aria-labelledby="pickup-reminder-title"
      class="m-auto w-[calc(100%-2rem)] max-w-lg rounded-2xl border border-n-amber-6 bg-n-surface-1 text-n-slate-12 shadow-2xl backdrop:bg-black/50"
      @cancel.prevent
    >
      <div class="p-5 sm:p-6">
        <div class="mb-4 flex items-center gap-3">
          <span
            class="grid size-11 shrink-0 place-items-center rounded-xl bg-n-amber-4 text-n-amber-11"
          >
            <Icon icon="i-lucide-bell-ring" class="size-5" />
          </span>
          <div>
            <h2 id="pickup-reminder-title" class="text-lg font-semibold">
              {{ $t('ROTTA_PICKUP.REMINDER') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ $t('ROTTA_PICKUP.REMINDER_DESCRIPTION') }}
            </p>
          </div>
        </div>
        <ul class="max-h-[45vh] space-y-2 overflow-auto">
          <li
            v-for="item in reminders"
            :key="item.id"
            class="rounded-xl border border-n-amber-5 bg-n-amber-2 px-3 py-2"
          >
            <div class="text-xs font-semibold text-n-amber-11">
              {{ timing(item.days_until) }}
            </div>
            <PickupContactName
              :name="item.name"
              :suffix="item.date_label"
              class="break-words text-sm font-medium"
            />
            <p
              v-if="item.note"
              class="mt-1 break-words text-xs text-n-slate-11"
            >
              {{ item.note }}
            </p>
          </li>
        </ul>
        <p v-if="error" role="alert" class="mt-3 text-sm text-n-ruby-11">
          {{ $t('ROTTA_PICKUP.ACK_ERROR') }}
        </p>
        <div class="mt-5 flex justify-end">
          <button
            type="button"
            :disabled="acknowledging"
            class="rounded-lg bg-n-brand px-5 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="acknowledge"
          >
            {{
              acknowledging ? $t('ROTTA_PICKUP.ACKING') : $t('ROTTA_PICKUP.OK')
            }}
          </button>
        </div>
      </div>
    </dialog>
  </Teleport>
</template>
