<script setup>
import { useI18n } from 'vue-i18n';
import { onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PickupContactName from 'dashboard/components-next/Conversation/Pickups/PickupContactName.vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import {
  pickupRevision,
  confirmPickupDate,
  announcePickupChange,
} from 'dashboard/composables/useRottaPickupDialog';
import api from 'dashboard/api/rottaPickups';

const { t } = useI18n();

const store = useStore();
const route = useRoute();
const items = ref([]);
const page = ref(1);
const total = ref(0);
const hasMore = ref(false);
const loading = ref(true);
const error = ref(false);
const completing = ref(null);
let request = 0;

const load = async (nextPage = page.value) => {
  request += 1;
  const version = request;
  loading.value = true;
  error.value = false;
  try {
    const { data } = await api.page(nextPage);
    if (version !== request) return;
    items.value = data.items;
    total.value = data.total;
    page.value = data.page;
    hasMore.value = data.has_more;
  } catch {
    if (version === request) error.value = true;
  } finally {
    if (version === request) loading.value = false;
  }
};

const complete = async item => {
  if (completing.value) return;
  completing.value = item.id;
  try {
    const { data } = await api.complete(item.id, item);
    store.dispatch('conversationLabels/setConversationLabel', {
      id: item.id,
      data: data.labels,
    });
    items.value = items.value.filter(row => row.id !== item.id);
    store.dispatch('labels/get', { forceNetwork: true });
    announcePickupChange();
    useAlert(t('ROTTA_PICKUP.COMPLETE_OK'));
  } catch (err) {
    useAlert(err.response?.data?.error || t('ROTTA_PICKUP.COMPLETE_ERROR'));
    load();
  } finally {
    completing.value = null;
  }
};

const edit = item =>
  confirmPickupDate(item.id, pickup =>
    store.dispatch('conversationLabels/mutate', {
      conversationId: item.id,
      pickup,
    })
  );

const openConversation = id => ({
  name: 'conversations_through_label',
  params: {
    accountId: route.params.accountId,
    label: 'clientes-fechados',
    conversation_id: id,
  },
});

const timing = item => {
  if (item.days_until === 0)
    return item.ends_on
      ? t('ROTTA_PICKUP.WINDOW_TODAY')
      : t('ROTTA_PICKUP.TODAY');
  if (item.days_until > 0)
    return item.days_until === 1
      ? t('ROTTA_PICKUP.TOMORROW')
      : t('ROTTA_PICKUP.IN_DAYS', { days: item.days_until });
  return item.ends_on
    ? t('ROTTA_PICKUP.WINDOW_STARTED')
    : t('ROTTA_PICKUP.PAST');
};

const refresh = () => {
  if (!document.hidden && !loading.value) load();
};

onMounted(() => {
  load();
  window.addEventListener('focus', refresh);
});
onUnmounted(() => window.removeEventListener('focus', refresh));
watch(pickupRevision, () => load());
watch(
  () => route.params.accountId,
  () => {
    items.value = [];
    load(1);
  }
);
</script>

<template>
  <section class="h-full min-w-0 flex-1 overflow-y-auto bg-n-background">
    <div class="mx-auto max-w-5xl px-4 py-6 sm:px-8 sm:py-10">
      <header
        class="mb-6 flex flex-wrap items-start justify-between gap-4 border-b border-n-weak pb-5"
      >
        <div class="flex min-w-0 items-center gap-3">
          <span
            class="grid size-11 shrink-0 place-items-center rounded-xl bg-n-amber-3 text-n-amber-11"
          >
            <Icon icon="i-lucide-truck" class="size-5" />
          </span>
          <div>
            <h1 class="text-xl font-semibold text-n-slate-12 sm:text-2xl">
              {{ $t('ROTTA_PICKUP.TITLE') }}
            </h1>
            <p class="text-sm text-n-slate-11">
              {{ $t('ROTTA_PICKUP.SUBTITLE') }}
            </p>
          </div>
        </div>
        <button
          type="button"
          :disabled="loading"
          class="rounded-lg border border-n-weak px-3 py-2 text-sm hover:bg-n-alpha-2 disabled:opacity-50"
          @click="load()"
        >
          {{ $t('ROTTA_PICKUP.REFRESH') }}
        </button>
      </header>
      <p v-if="error" role="alert" class="mb-3 text-sm text-n-ruby-11">
        {{ $t('ROTTA_PICKUP.LOAD_ERROR') }}
      </p>
      <p
        v-if="loading && !items.length"
        role="status"
        class="text-sm text-n-slate-11"
      >
        {{ $t('ROTTA_PICKUP.LOADING_PICKUPS') }}
      </p>
      <div
        v-if="!loading && !error && !items.length"
        class="rounded-xl border border-n-weak bg-n-surface-1 p-6 text-sm text-n-slate-11"
      >
        {{ $t('ROTTA_PICKUP.EMPTY') }}
      </div>
      <p v-if="items.length" class="mb-3 text-sm text-n-slate-11">
        {{ $t('ROTTA_PICKUP.COUNT', total) }}
      </p>
      <ul class="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <li
          v-for="item in items"
          :key="item.id"
          class="flex min-w-0 flex-col gap-3 rounded-xl border border-n-weak bg-n-surface-1 p-4"
        >
          <div class="flex flex-wrap items-center gap-2">
            <span
              class="rounded-full bg-n-amber-3 px-2.5 py-1 text-xs font-semibold text-n-amber-11"
              >{{ timing(item) }}</span
            >
            <span class="text-xs text-n-slate-11">{{
              item.ends_on && item.ends_on !== item.starts_on
                ? $t('ROTTA_PICKUP.FLEX')
                : $t('ROTTA_PICKUP.FIXED')
            }}</span>
          </div>
          <RouterLink
            :to="openConversation(item.id)"
            class="min-w-0 break-words font-semibold text-n-slate-12 hover:underline"
          >
            <PickupContactName :name="item.name" :suffix="item.date_label" />
          </RouterLink>
          <p v-if="item.note" class="break-words text-sm text-n-slate-11">
            {{ item.note }}
          </p>
          <div
            class="mt-auto flex flex-wrap items-center justify-end gap-2 border-t border-n-weak pt-3"
          >
            <button
              type="button"
              class="rounded-lg px-3 py-2 text-sm hover:bg-n-alpha-2"
              @click="edit(item)"
            >
              {{ $t('ROTTA_PICKUP.CHANGE') }}
            </button>
            <button
              type="button"
              :disabled="Boolean(completing)"
              class="rounded-lg bg-n-teal-3 px-3 py-2 text-sm font-semibold text-n-teal-11 hover:bg-n-teal-4 disabled:opacity-50"
              @click="complete(item)"
            >
              {{
                completing === item.id
                  ? $t('ROTTA_PICKUP.COMPLETING')
                  : $t('ROTTA_PICKUP.COMPLETE')
              }}
            </button>
          </div>
        </li>
      </ul>
      <nav
        v-if="page > 1 || hasMore"
        :aria-label="$t('ROTTA_PICKUP.PAGINATION')"
        class="mt-5 flex items-center justify-between gap-3 text-sm"
      >
        <button
          type="button"
          :disabled="page === 1 || loading"
          class="rounded-lg border border-n-weak px-3 py-2 disabled:opacity-50"
          @click="load(page - 1)"
        >
          {{ $t('ROTTA_PICKUP.PREV') }}
        </button>
        <span>{{ $t('ROTTA_PICKUP.PAGE', { page }) }}</span>
        <button
          type="button"
          :disabled="!hasMore || loading"
          class="rounded-lg border border-n-weak px-3 py-2 disabled:opacity-50"
          @click="load(page + 1)"
        >
          {{ $t('ROTTA_PICKUP.NEXT') }}
        </button>
      </nav>
    </div>
  </section>
</template>
