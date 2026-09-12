<script setup>
import { computed } from 'vue';
import { formatNumber } from '@chatwoot/utils';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import FilterSelect from 'dashboard/components-next/filter/inputs/FilterSelect.vue';

const props = defineProps({
  pageTitle: { type: String, required: true },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
  searchQuery: { type: String, default: '' },
  labelFilterOptions: { type: Array, default: () => [] },
  activeLabelFilter: { type: String, default: '' },
  activeLabelCount: { type: Number, default: null },
  showLabelFilter: { type: Boolean, default: false },
  showRottaShortcuts: { type: Boolean, default: false },
  isMarkingAllAsRead: { type: Boolean, default: false },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
  'labelFilterChange',
  'updateSearchQuery',
  'markAllAsRead',
]);

const rottaCopy = {
  markAllRead: 'Marcar tudo como lido',
  searchPlaceholder: 'Pesquisar conversas...',
  searchLabel: 'Pesquisar conversas',
  clearSearch: 'Limpar pesquisa',
  newConversation: 'Iniciar nova conversa',
};

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => {
  if (props.activeLabelCount !== null) return props.activeLabelCount;
  return props.conversationStats?.allCount || 0;
});
const formattedAllCount = computed(() => formatNumber(allCount.value));
</script>

<template>
  <div
    class="flex flex-col gap-2 px-3 py-2"
    :class="{
      'border-b border-n-strong': hasAppliedFiltersOrActiveFolders,
    }"
  >
    <div
      class="flex items-center justify-between gap-2 min-w-0 rotta-chat-list-header"
    >
      <div class="flex items-center min-w-0">
        <h1
          class="text-base font-medium truncate text-n-slate-12"
          :title="pageTitle"
        >
          {{ pageTitle }}
        </h1>
        <span
          v-if="
            allCount > 0 && hasAppliedFiltersOrActiveFolders && !isListLoading
          "
          class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
          :title="allCount"
        >
          {{ formattedAllCount }}
        </span>
        <span
          v-if="!hasAppliedFiltersOrActiveFolders && activeStatus !== 'all'"
          class="px-2 py-1 my-0.5 mx-1 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
        >
          {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
        </span>
        <div
          v-if="showRottaShortcuts"
          class="flex items-center gap-1 ml-1 shrink-0"
        >
          <NextButton
            v-tooltip.top="rottaCopy.markAllRead"
            icon="i-lucide-mail-check"
            label="Ler tudo"
            slate
            xs
            faded
            :is-loading="isMarkingAllAsRead"
            @click="emit('markAllAsRead')"
          />
        </div>
      </div>
      <div class="flex items-center gap-1 shrink-0">
        <template v-if="hasAppliedFilters && !hasActiveFolders">
          <div class="relative">
            <NextButton
              v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
              icon="i-lucide-save"
              slate
              xs
              faded
              @click="emit('addFolders')"
            />
            <div
              id="saveFilterTeleportTarget"
              class="absolute z-50 mt-2"
              :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
            />
          </div>
          <NextButton
            v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
            icon="i-lucide-circle-x"
            ruby
            faded
            xs
            @click="emit('resetFilters')"
          />
        </template>
        <template v-if="hasActiveFolders">
          <div class="relative">
            <NextButton
              id="toggleConversationFilterButton"
              v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
              icon="i-lucide-pen-line"
              slate
              xs
              faded
              @click="emit('filtersModal')"
            />
            <div
              id="conversationFilterTeleportTarget"
              class="absolute z-50 mt-2"
              :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
            />
          </div>
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
            icon="i-lucide-trash-2"
            ruby
            xs
            faded
            @click="emit('deleteFolders')"
          />
        </template>
        <FilterSelect
          v-if="showLabelFilter"
          :model-value="activeLabelFilter"
          :options="labelFilterOptions"
          @update:model-value="emit('labelFilterChange', $event)"
        />
        <div v-if="!hasActiveFolders" class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
            icon="i-lucide-list-filter"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <ConversationBasicFilter
          v-if="!hasAppliedFiltersOrActiveFolders"
          :is-on-expanded-layout="isOnExpandedLayout"
          @change-filter="onBasicFilterChange"
        />
      </div>
    </div>
    <div class="flex items-center gap-2">
      <div class="relative flex-1 min-w-0 rotta-conversation-search">
        <span
          class="absolute top-1/2 ltr:left-2.5 rtl:right-2.5 flex size-4 -translate-y-1/2 items-center justify-center pointer-events-none i-lucide-search text-n-slate-10"
        />
        <input
          id="conversation-search"
          :value="searchQuery"
          type="search"
          autocomplete="off"
          :placeholder="rottaCopy.searchPlaceholder"
          :aria-label="rottaCopy.searchLabel"
          class="w-full h-8 ltr:pl-8 rtl:pr-8 ltr:pr-9 rtl:pl-9 rounded-xl outline outline-1 outline-n-weak bg-n-surface-2 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-n-brand"
          @input="emit('updateSearchQuery', $event.target.value)"
          @keydown.esc.prevent="emit('updateSearchQuery', '')"
        />
        <button
          v-if="searchQuery"
          type="button"
          class="absolute top-1/2 ltr:right-1 rtl:left-1 flex items-center justify-center size-6 -translate-y-1/2 rounded-lg text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          :aria-label="rottaCopy.clearSearch"
          :title="rottaCopy.clearSearch"
          @click="emit('updateSearchQuery', '')"
        >
          <span class="i-lucide-x size-3.5" aria-hidden="true" />
        </button>
      </div>
      <ComposeConversation align="start">
        <template #trigger="{ isOpen }">
          <NextButton
            v-tooltip.top="rottaCopy.newConversation"
            icon="i-lucide-plus"
            slate
            xs
            faded
            :class="{ '!bg-n-alpha-2 dark:!bg-n-slate-9/30': isOpen }"
            :aria-label="rottaCopy.newConversation"
          />
        </template>
      </ComposeConversation>
    </div>
  </div>
</template>

<style scoped>
/* Keep the clear affordance consistent across Chromium, Firefox, and Safari. */
:global(.rotta-conversation-search input::-webkit-search-cancel-button) {
  display: none;
  appearance: none;
}

@media (max-width: 479px) {
  .rotta-chat-list-header {
    align-items: flex-start;
    flex-wrap: wrap;
  }

  .rotta-chat-list-header > :first-child {
    flex: 0 0 10rem;
    min-width: 0;
    overflow: hidden;
  }

  .rotta-chat-list-header > :last-child {
    flex: 0 0 100%;
    justify-content: flex-start;
  }
}
</style>
