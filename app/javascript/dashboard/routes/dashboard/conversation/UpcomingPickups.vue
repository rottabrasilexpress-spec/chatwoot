<script setup>
import { useI18n } from 'vue-i18n';
import { onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import {
  pickupRevision,
  editPickupDates,
  announcePickupChange,
} from 'dashboard/composables/useRottaPickupDialog';
import api from 'dashboard/api/rottaPickups';
import {
  isFlexiblePickup,
  pickupDateLabel,
  splitPickupName,
} from 'dashboard/helper/rottaPickup';

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
const layoutOptions = [
  {
    id: 'cards',
    title: () => t('ROTTA_PICKUP.LAYOUT_CARDS'),
    icon: 'i-lucide-layout-grid',
  },
  {
    id: 'list',
    title: () => t('ROTTA_PICKUP.LAYOUT_LIST'),
    icon: 'i-lucide-list',
  },
  {
    id: 'large',
    title: () => t('ROTTA_PICKUP.LAYOUT_LARGE'),
    icon: 'i-lucide-panels-top-left',
  },
];
const layoutKey = 'rotta-upcoming-moves-layout';
const layout = ref('cards');
let request = 0;

const chooseLayout = selected => {
  layout.value = selected;
  try {
    localStorage.setItem(layoutKey, selected);
  } catch {
    // Layout switching remains available if storage is blocked.
  }
};

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

const openConversation = id => ({
  name: 'conversations_through_label',
  params: {
    accountId: route.params.accountId,
    label: 'clientes-fechados',
    conversation_id: id,
  },
});

const timing = item => {
  if (item.pickup_overdue) return t('ROTTA_PICKUP.PAST');
  if (item.days_until === 0)
    return isFlexiblePickup(item)
      ? t('ROTTA_PICKUP.WINDOW_TODAY')
      : t('ROTTA_PICKUP.TODAY');
  if (item.days_until > 0)
    return item.days_until === 1
      ? t('ROTTA_PICKUP.TOMORROW')
      : t('ROTTA_PICKUP.IN_DAYS', { days: item.days_until });
  return isFlexiblePickup(item)
    ? t('ROTTA_PICKUP.WINDOW_STARTED')
    : t('ROTTA_PICKUP.PAST');
};

const refresh = () => {
  if (!document.hidden && !loading.value) load();
};

onMounted(() => {
  try {
    const savedLayout = localStorage.getItem(layoutKey);
    if (layoutOptions.some(option => option.id === savedLayout)) {
      layout.value = savedLayout;
    }
  } catch {
    // Keep the default layout if storage is blocked.
  }
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
    <div class="w-full px-4 py-5 sm:px-7 sm:py-7 2xl:px-10">
      <header
        class="mb-5 flex flex-wrap items-center justify-between gap-4 rounded-2xl border border-n-amber-5 bg-n-amber-2 p-4 sm:p-5"
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
        <div class="flex min-w-0 flex-wrap items-center gap-2">
          <div
            role="group"
            :aria-label="$t('ROTTA_PICKUP.LAYOUT')"
            class="flex min-w-0 flex-wrap gap-1 rounded-xl border border-n-weak bg-n-surface-1 p-1"
          >
            <button
              v-for="option in layoutOptions"
              :key="option.id"
              type="button"
              :aria-pressed="layout === option.id"
              class="inline-flex min-h-9 items-center gap-1.5 rounded-lg px-2.5 text-xs font-medium"
              :class="
                layout === option.id
                  ? 'bg-n-amber-4 text-n-amber-11'
                  : 'text-n-slate-11 hover:bg-n-alpha-2'
              "
              @click="chooseLayout(option.id)"
            >
              <Icon :icon="option.icon" class="size-4" />
              {{ option.title() }}
            </button>
          </div>
          <button
            type="button"
            :disabled="loading"
            class="inline-flex min-h-10 items-center gap-1.5 rounded-xl border border-n-weak bg-n-surface-1 px-3 text-sm hover:bg-n-alpha-2 disabled:opacity-50"
            @click="load()"
          >
            <Icon icon="i-lucide-refresh-cw" class="size-4" />
            {{ $t('ROTTA_PICKUP.REFRESH') }}
          </button>
        </div>
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
      <ul
        class="grid grid-cols-1 gap-3"
        :class="{
          'md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4': layout === 'cards',
          'xl:grid-cols-2': layout === 'large',
        }"
      >
        <li
          v-for="item in items"
          :key="item.id"
          class="flex min-w-0 flex-col gap-3 rounded-2xl border border-n-weak bg-n-surface-1 shadow-sm"
          :class="layout === 'large' ? 'p-5 sm:p-6' : 'p-4'"
        >
          <div
            class="grid min-w-0 gap-3"
            :class="{
              'lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)] lg:items-center':
                layout === 'list',
            }"
          >
            <RouterLink
              :to="openConversation(item.id)"
              :title="$t('ROTTA_PICKUP.OPEN_CHAT')"
              class="group flex min-w-0 items-center gap-3 rounded-lg text-n-slate-12"
            >
              <span
                class="grid size-10 shrink-0 place-items-center rounded-xl bg-n-teal-3 text-n-teal-11 group-hover:bg-n-teal-4"
              >
                <Icon icon="i-ri-whatsapp-fill" class="size-5" />
              </span>
              <span class="min-w-0">
                <span
                  class="block break-words font-semibold group-hover:underline"
                  :class="{ 'text-lg': layout === 'large' }"
                >
                  {{ splitPickupName(item.name, item.date_label)[0] }}
                </span>
                <span
                  v-if="item.phone"
                  class="block break-words text-xs tabular-nums text-n-slate-11"
                >
                  {{ item.phone }}
                </span>
              </span>
            </RouterLink>
            <div class="grid min-w-0 gap-2 sm:grid-cols-2">
              <div
                class="min-w-0 rounded-xl border border-n-amber-5 bg-n-amber-2 px-3 py-2.5"
              >
                <p
                  class="flex items-center gap-1.5 text-xs font-medium text-n-amber-11"
                >
                  <Icon icon="i-lucide-calendar-days" class="size-4 shrink-0" />
                  {{ $t('ROTTA_PICKUP.DATE') }}
                </p>
                <p
                  class="mt-1 break-words text-sm font-semibold tabular-nums text-n-slate-12"
                >
                  {{ pickupDateLabel(item.starts_on, item.ends_on) }}
                </p>
                <p class="mt-0.5 text-xs text-n-amber-11">{{ timing(item) }}</p>
              </div>
              <div
                class="min-w-0 rounded-xl border border-n-blue-5 bg-n-blue-2 px-3 py-2.5"
              >
                <p
                  class="flex items-center gap-1.5 text-xs font-medium text-n-blue-11"
                >
                  <Icon icon="i-lucide-package-check" class="size-4 shrink-0" />
                  {{ $t('ROTTA_PICKUP.DELIVERY_DATE') }}
                </p>
                <p
                  v-if="item.delivery_on"
                  class="mt-1 break-words text-sm font-semibold tabular-nums text-n-slate-12"
                >
                  {{ pickupDateLabel(item.delivery_on) }}
                </p>
                <button
                  v-else
                  type="button"
                  class="mt-1 text-sm text-n-blue-11 underline"
                  @click="editPickupDates(item.id, store)"
                >
                  {{ $t('ROTTA_PICKUP.ADD_DELIVERY') }}
                </button>
              </div>
            </div>
          </div>
          <p v-if="item.note" class="break-words text-sm text-n-slate-11">
            {{ item.note }}
          </p>
          <div
            class="mt-auto flex flex-wrap items-center justify-end gap-2 border-t border-n-weak pt-3"
          >
            <button
              v-if="isFlexiblePickup(item)"
              type="button"
              class="rounded-lg bg-n-amber-3 px-3 py-2 text-sm font-medium text-n-amber-11 hover:bg-n-amber-4"
              @click="editPickupDates(item.id, store, true)"
            >
              {{ $t('ROTTA_PICKUP.CONFIRM_DATE') }}
            </button>
            <button
              type="button"
              class="rounded-lg px-3 py-2 text-sm hover:bg-n-alpha-2"
              @click="editPickupDates(item.id, store)"
            >
              {{ $t('ROTTA_PICKUP.EDIT_DATES') }}
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
