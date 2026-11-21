<script setup>
import { useI18n } from 'vue-i18n';
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
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
import ConversationAiAPI from 'dashboard/api/captain/conversationAi';
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
const fillingRoute = ref(null);
const routeFields = computed(() => [
  { key: 'origin', title: t('ROTTA_PICKUP.ORIGIN') },
  { key: 'destination', title: t('ROTTA_PICKUP.DESTINATION') },
]);
const layoutOptions = [
  {
    id: 'list',
    title: () => t('ROTTA_PICKUP.LAYOUT_LIST'),
    icon: 'i-lucide-list',
    columns: 'grid-cols-1',
  },
  {
    id: 'large',
    title: () => t('ROTTA_PICKUP.LAYOUT_LARGE'),
    icon: 'i-lucide-panels-top-left',
    columns: 'grid-cols-1 xl:grid-cols-2',
  },
  {
    id: 'cards',
    title: () => t('ROTTA_PICKUP.LAYOUT_CARDS'),
    icon: 'i-lucide-layout-grid',
    columns: 'grid-cols-1 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4',
  },
  {
    id: 'compact',
    title: () => t('ROTTA_PICKUP.LAYOUT_COMPACT'),
    icon: 'i-lucide-grid-3x3',
    columns: 'grid-cols-[repeat(auto-fill,minmax(min(100%,19rem),1fr))]',
  },
  {
    id: 'mini',
    title: () => t('ROTTA_PICKUP.LAYOUT_MINI'),
    icon: 'i-lucide-grip',
    columns: 'grid-cols-[repeat(auto-fill,minmax(min(100%,14rem),1fr))]',
  },
];
const layoutKey = 'rotta-upcoming-moves-layout';
const layout = ref('cards');
const gridColumns = computed(
  () => layoutOptions.find(option => option.id === layout.value)?.columns
);
const dense = computed(() => ['compact', 'mini'].includes(layout.value));
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

const fillRoute = async item => {
  if (fillingRoute.value) return;
  fillingRoute.value = item.id;
  try {
    const { data } = await ConversationAiAPI.profile(item.id, {
      routeOnly: true,
    });
    const { origin, destination } = data.profile || {};
    const row = items.value.find(move => move.id === item.id);
    if (row) row.route = { origin, destination };
    useAlert(
      origin && destination
        ? t('ROTTA_PICKUP.ROUTE_SAVED')
        : t('ROTTA_PICKUP.ROUTE_INCOMPLETE')
    );
  } catch (err) {
    useAlert(err.response?.data?.error || t('ROTTA_PICKUP.ROUTE_ERROR'));
  } finally {
    fillingRoute.value = null;
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
      ? t('ROTTA_PICKUP.ONE_DAY')
      : t('ROTTA_PICKUP.COLLECTION_COUNTDOWN', { days: item.days_until });
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
      <ul class="grid gap-x-3 gap-y-4" :class="gridColumns">
        <li
          v-for="item in items"
          :key="item.id"
          class="flex min-w-0 flex-col rounded-xl border-2 border-n-slate-6 bg-n-surface-1"
          :class="{
            'gap-3 p-5 sm:p-6': layout === 'large',
            'gap-3 p-4': layout === 'cards' || layout === 'list',
            'gap-2.5 p-3': layout === 'compact',
            'gap-2 p-2.5': layout === 'mini',
          }"
        >
          <div
            class="grid min-w-0 gap-3"
            :class="{
              'lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)] lg:items-center':
                layout === 'list',
            }"
          >
            <div
              class="flex min-w-0 flex-wrap items-start justify-between gap-x-3 gap-y-2"
              :class="{ 'flex-col': dense || layout === 'list' }"
            >
              <RouterLink
                :to="openConversation(item.id)"
                :title="$t('ROTTA_PICKUP.OPEN_CHAT')"
                class="group flex min-w-0 max-w-full flex-1 items-center gap-2 rounded-lg text-n-slate-12"
              >
                <span
                  class="grid shrink-0 place-items-center rounded-lg bg-n-teal-3 text-n-teal-11 group-hover:bg-n-teal-4"
                  :class="dense ? 'size-8' : 'size-10'"
                >
                  <Icon
                    icon="i-ri-whatsapp-fill"
                    :class="dense ? 'size-4' : 'size-5'"
                  />
                </span>
                <span class="min-w-0">
                  <span
                    class="block break-words font-semibold leading-snug group-hover:underline"
                    :class="{ 'text-lg': layout === 'large', 'text-sm': dense }"
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
              <p
                class="flex max-w-full items-center gap-1.5 rounded-md bg-n-ruby-3 px-2 py-1 font-bold leading-snug text-n-ruby-11 tabular-nums"
                :class="layout === 'mini' ? 'text-sm' : 'text-base'"
              >
                <Icon icon="i-lucide-clock-3" class="size-4 shrink-0" />
                <span class="min-w-0 break-words">{{ timing(item) }}</span>
              </p>
            </div>
            <div class="grid min-w-0 grid-cols-2 items-stretch gap-2">
              <div
                class="min-w-0 rounded-lg bg-n-amber-2 text-center"
                :class="dense ? 'p-2' : 'px-3 py-2.5'"
              >
                <p
                  class="flex items-center justify-center gap-1.5 text-xs font-medium text-n-amber-11"
                >
                  <Icon icon="i-lucide-calendar-days" class="size-4 shrink-0" />
                  {{ $t('ROTTA_PICKUP.COLLECTION_SHORT') }}
                </p>
                <p
                  class="mt-1 break-words font-semibold leading-snug tabular-nums text-n-slate-12"
                  :class="layout === 'mini' ? 'text-xs' : 'text-sm'"
                >
                  {{ pickupDateLabel(item.starts_on, item.ends_on) }}
                </p>
              </div>
              <div
                class="min-w-0 rounded-lg text-center"
                :class="[
                  dense ? 'p-2' : 'px-3 py-2.5',
                  item.delivery_on
                    ? 'bg-n-teal-2 text-n-teal-11'
                    : 'bg-n-alpha-2 text-n-slate-11',
                ]"
              >
                <p
                  class="flex items-center justify-center gap-1.5 text-xs font-medium"
                >
                  <Icon icon="i-lucide-package-check" class="size-4 shrink-0" />
                  {{ $t('ROTTA_PICKUP.DELIVERY_SHORT') }}
                </p>
                <p
                  v-if="item.delivery_on"
                  class="mt-1 break-words font-semibold leading-snug tabular-nums"
                  :class="layout === 'mini' ? 'text-xs' : 'text-sm'"
                >
                  {{ pickupDateLabel(item.delivery_on) }}
                </p>
                <div
                  v-else
                  class="mt-1 flex flex-wrap items-center justify-center gap-1.5 text-xs"
                >
                  <span>{{ $t('ROTTA_PICKUP.PENDING') }}</span>
                  <button
                    type="button"
                    class="grid size-7 shrink-0 place-items-center rounded-md border border-n-weak hover:bg-n-alpha-2"
                    :aria-label="$t('ROTTA_PICKUP.ADD_DELIVERY')"
                    :title="$t('ROTTA_PICKUP.ADD_DELIVERY')"
                    @click="
                      editPickupDates(item.id, store, { focusDelivery: true })
                    "
                  >
                    <Icon icon="i-lucide-plus" class="size-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div class="min-w-0 rounded-lg border border-n-weak px-2.5 py-2">
            <dl class="grid min-w-0 grid-cols-2 gap-2">
              <div
                v-for="field in routeFields"
                :key="field.key"
                class="min-w-0"
              >
                <dt class="text-xs font-medium text-n-slate-11">
                  {{ field.title }}
                </dt>
                <dd
                  class="mt-0.5 break-words text-sm font-medium text-n-slate-12"
                >
                  {{ item.route?.[field.key] || $t('ROTTA_PICKUP.PENDING') }}
                </dd>
              </div>
            </dl>
            <button
              v-if="!item.route?.origin || !item.route?.destination"
              type="button"
              class="mt-1.5 inline-flex min-h-8 items-center gap-1.5 rounded border border-n-weak px-2 text-xs font-medium text-n-brand hover:bg-n-alpha-2 disabled:opacity-50"
              :disabled="Boolean(fillingRoute)"
              @click="fillRoute(item)"
            >
              <Icon icon="i-lucide-sparkles" class="size-3.5" />
              {{
                fillingRoute === item.id
                  ? $t('ROTTA_PICKUP.READING_ROUTE')
                  : $t('ROTTA_PICKUP.FILL_ROUTE')
              }}
            </button>
          </div>
          <details
            v-if="item.note && layout === 'mini'"
            class="min-w-0 text-xs text-n-slate-11"
          >
            <summary class="cursor-pointer font-medium">
              {{ $t('ROTTA_PICKUP.NOTE') }}
            </summary>
            <p class="mt-1 break-words">{{ item.note }}</p>
          </details>
          <p v-else-if="item.note" class="break-words text-sm text-n-slate-11">
            {{ item.note }}
          </p>
          <div
            class="mt-auto flex flex-wrap items-center justify-end gap-1.5 border-t border-n-slate-5"
            :class="dense ? 'pt-2' : 'pt-3'"
          >
            <button
              v-if="isFlexiblePickup(item)"
              type="button"
              :aria-label="$t('ROTTA_PICKUP.CONFIRM_DATE')"
              class="min-h-9 rounded-lg bg-n-amber-3 font-medium text-n-amber-11 hover:bg-n-amber-4"
              :class="dense ? 'px-2 text-xs' : 'px-3 text-sm'"
              @click="editPickupDates(item.id, store, { confirmWindow: true })"
            >
              {{
                dense
                  ? $t('ROTTA_PICKUP.CONFIRM_SHORT')
                  : $t('ROTTA_PICKUP.CONFIRM_DATE')
              }}
            </button>
            <button
              type="button"
              :aria-label="$t('ROTTA_PICKUP.EDIT_DATES')"
              class="min-h-9 rounded-lg hover:bg-n-alpha-2"
              :class="dense ? 'px-2 text-xs' : 'px-3 text-sm'"
              @click="editPickupDates(item.id, store)"
            >
              {{
                dense
                  ? $t('ROTTA_PICKUP.EDIT_SHORT')
                  : $t('ROTTA_PICKUP.EDIT_DATES')
              }}
            </button>
            <button
              type="button"
              :disabled="Boolean(completing)"
              :aria-label="$t('ROTTA_PICKUP.COMPLETE')"
              class="min-h-9 rounded-lg bg-n-teal-3 font-semibold text-n-teal-11 hover:bg-n-teal-4 disabled:opacity-50"
              :class="dense ? 'px-2 text-xs' : 'px-3 text-sm'"
              @click="complete(item)"
            >
              {{
                completing === item.id
                  ? $t('ROTTA_PICKUP.COMPLETING')
                  : dense
                    ? $t('ROTTA_PICKUP.COMPLETE_SHORT')
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
