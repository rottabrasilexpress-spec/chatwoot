<script setup>
import { useI18n } from 'vue-i18n';
import { computed, nextTick, ref, watch } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import api from 'dashboard/api/rottaPickups';
import {
  isValidPickupDate,
  pickupDateLabel,
} from 'dashboard/helper/rottaPickup';
import {
  pickupRequest,
  finishPickupDialog,
} from 'dashboard/composables/useRottaPickupDialog';

const { t } = useI18n();

const dialog = ref(null);
const name = ref('');
const startsOn = ref('');
const endsOn = ref('');
const flexible = ref(false);
const note = ref('');
const loading = ref(false);
const saving = ref(false);
const error = ref('');

const valid = computed(
  () =>
    isValidPickupDate(startsOn.value) &&
    (!flexible.value ||
      (isValidPickupDate(endsOn.value) && endsOn.value >= startsOn.value))
);
const preview = computed(() =>
  pickupDateLabel(startsOn.value, flexible.value ? endsOn.value : '')
);

watch(
  pickupRequest,
  async request => {
    if (!request) return;
    name.value = '';
    startsOn.value = '';
    endsOn.value = '';
    note.value = '';
    flexible.value = false;
    error.value = '';
    loading.value = true;
    await nextTick();
    if (request !== pickupRequest.value) return;
    dialog.value?.showModal();
    try {
      const { data } = await api.show(request.conversationId);
      if (request !== pickupRequest.value) return;
      name.value = data.name;
      startsOn.value = data.pickup?.starts_on || '';
      endsOn.value = data.pickup?.ends_on || '';
      flexible.value = Boolean(endsOn.value);
      note.value = data.pickup?.note || '';
    } catch {
      if (request === pickupRequest.value)
        error.value = t('ROTTA_PICKUP.LOOKUP_ERROR');
    } finally {
      if (request === pickupRequest.value) loading.value = false;
    }
  },
  { immediate: true }
);

const close = () => {
  if (saving.value) return;
  dialog.value?.close();
  finishPickupDialog({ status: 'cancelled' });
};

const save = async () => {
  if (!valid.value || loading.value || saving.value || !pickupRequest.value)
    return;
  saving.value = true;
  error.value = '';
  try {
    const result = await pickupRequest.value.save({
      starts_on: startsOn.value,
      ends_on: flexible.value ? endsOn.value : null,
      note: note.value,
    });
    if (result?.status !== 'success' && result !== true) {
      error.value = result?.error || t('ROTTA_PICKUP.FORM_ERROR');
      return;
    }
    dialog.value?.close();
    finishPickupDialog(result);
  } catch (err) {
    error.value = err.response?.data?.message || t('ROTTA_PICKUP.SAVE_ERROR');
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <Teleport to="body">
    <dialog
      ref="dialog"
      aria-labelledby="pickup-date-title"
      class="m-auto w-[calc(100%-2rem)] max-w-md rounded-2xl border border-n-weak bg-n-surface-1 text-n-slate-12 shadow-2xl backdrop:bg-black/50"
      @cancel.prevent="close"
    >
      <form class="flex flex-col gap-4 p-5 sm:p-6" @submit.prevent="save">
        <header class="flex items-start gap-3">
          <span
            class="grid size-10 shrink-0 place-items-center rounded-xl bg-n-amber-3 text-n-amber-11"
          >
            <Icon icon="i-lucide-calendar-days" class="size-5" />
          </span>
          <div class="min-w-0">
            <h2 id="pickup-date-title" class="text-lg font-semibold">
              {{ $t('ROTTA_PICKUP.DATE') }}
            </h2>
            <p class="text-sm text-n-slate-11">
              {{ name || $t('ROTTA_PICKUP.CLOSED') }}
            </p>
          </div>
        </header>
        <p class="text-sm text-n-slate-11">
          {{ $t('ROTTA_PICKUP.INSTRUCTIONS') }}
        </p>
        <fieldset
          :disabled="loading || saving"
          class="flex min-w-0 flex-col gap-3"
        >
          <label class="flex items-center gap-2 text-sm">
            <input
              v-model="flexible"
              type="checkbox"
              class="!m-0 accent-n-brand"
            />{{ $t('ROTTA_PICKUP.FLEX_PROMPT') }}</label
          >
          <div class="grid min-w-0 gap-3 sm:grid-cols-2">
            <label
              class="min-w-0 text-sm"
              :class="{ 'sm:col-span-2': !flexible }"
            >
              {{
                flexible ? $t('ROTTA_PICKUP.START') : $t('ROTTA_PICKUP.DATE')
              }}
              <input
                v-model="startsOn"
                type="date"
                required
                class="mt-1 !mb-0 w-full"
              />
            </label>
            <label v-if="flexible" class="min-w-0 text-sm">
              <span>{{ $t('ROTTA_PICKUP.END') }}</span>
              <input
                v-model="endsOn"
                type="date"
                :min="startsOn"
                required
                class="mt-1 !mb-0 w-full"
              />
            </label>
          </div>
          <label class="text-sm"
            >{{ $t('ROTTA_PICKUP.NOTE')
            }}<span class="text-n-slate-11">{{
              $t('ROTTA_PICKUP.OPTIONAL')
            }}</span>
            <input
              v-model="note"
              type="text"
              maxlength="240"
              :placeholder="$t('ROTTA_PICKUP.EXAMPLE')"
              class="mt-1 !mb-0 w-full"
            />
          </label>
        </fieldset>
        <p v-if="loading" role="status" class="text-sm text-n-slate-11">
          {{ $t('ROTTA_PICKUP.LOADING') }}
        </p>
        <p
          v-if="preview"
          class="rounded-lg bg-n-amber-2 px-3 py-2 text-sm font-semibold text-n-amber-11"
        >
          {{ preview }}
        </p>
        <p v-if="error" role="alert" class="text-sm text-n-ruby-11">
          {{ error }}
        </p>
        <footer class="flex flex-wrap justify-end gap-2">
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg px-3 py-2 text-sm hover:bg-n-alpha-2"
            @click="close"
          >
            {{ $t('ROTTA_PICKUP.CANCEL') }}
          </button>
          <button
            type="submit"
            :disabled="!valid || loading || saving"
            class="rounded-lg bg-n-brand px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          >
            {{ saving ? $t('ROTTA_PICKUP.SAVING') : $t('ROTTA_PICKUP.SAVE') }}
          </button>
        </footer>
      </form>
    </dialog>
  </Teleport>
</template>
