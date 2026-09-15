<script setup>
import { computed, useAttrs } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import { useBulkActions } from 'dashboard/composables/chatlist/useBulkActions.js';

import NextButton from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import BulkLabelActions from './BulkLabelActions.vue';

const props = defineProps({
  conversations: {
    type: Array,
    default: () => [],
  },
  allConversationsSelected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['selectAllConversations']);

defineOptions({
  inheritAttrs: false,
});

const attrs = useAttrs();
const { t } = useI18n();

const { selectedConversations, onAssignLabels, onRemoveLabels } =
  useBulkActions();

const getConversationById = useMapGetter('getConversationById');

const appliedLabelsForSelection = computed(() => {
  const applied = new Set();
  selectedConversations.value.forEach(id => {
    const conversation = getConversationById.value(id);
    (conversation?.labels || []).forEach(label => applied.add(label));
  });
  return Array.from(applied);
});

const selectedLabel = computed(() =>
  t('BULK_ACTION.CONVERSATIONS_SELECTED', {
    conversationCount: props.conversations.length,
  })
);

// Computed property with getter/setter to enable v-model usage
const allSelected = computed({
  get: () => props.allConversationsSelected,
  set: value => {
    emit('selectAllConversations', value);
  },
});
</script>

<template>
  <Transition
    enter-active-class="transition-all duration-200 ease-out origin-bottom"
    enter-from-class="opacity-0 scale-95 translate-y-2"
    enter-to-class="opacity-100 scale-100 translate-y-0"
    leave-active-class="transition-all duration-150 ease-in origin-bottom"
    leave-from-class="opacity-100 scale-100 translate-y-0"
    leave-to-class="opacity-0 scale-95 translate-y-2"
  >
    <div
      v-if="conversations.length > 0"
      v-bind="attrs"
      class="px-2 absolute bottom-20 sm:bottom-4 left-1/2 -translate-x-1/2 z-30 w-full origin-bottom"
    >
      <div
        v-if="allConversationsSelected"
        class="bg-n-amber-2 outline -outline-offset-1 outline-1 outline-n-amber-5 rounded-lg text-sm mb-2 py-1.5 px-2 text-n-amber-text"
      >
        {{ $t('BULK_ACTION.ALL_CONVERSATIONS_SELECTED_ALERT') }}
      </div>
      <div
        class="flex items-center justify-between gap-2 p-2 bg-n-button-color outline outline-1 -outline-offset-1 rounded-[10px] outline-n-weak shadow-[0_0_12px_0_rgba(27,40,59,0.08)]"
      >
        <div class="ms-0.5 flex items-center gap-1 min-w-0">
          <label class="cursor-pointer flex items-center gap-1.5 min-w-0">
            <Checkbox
              v-model="allSelected"
              :indeterminate="!allConversationsSelected"
              class="flex-shrink-0"
            />
            <span :title="selectedLabel" class="cursor-pointer truncate">
              {{ selectedLabel }}
            </span>
          </label>
          <div class="w-px h-3 bg-n-weak rounded-lg ms-1 flex-shrink-0" />
          <NextButton
            :label="$t('BULK_ACTION.CLEAR_SELECTION')"
            ghost
            class="!text-n-blue-11 !px-1 !h-6 flex-shrink-0"
            sm
            @click="allSelected = false"
          />
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <BulkLabelActions @assign="onAssignLabels" />
          <BulkLabelActions
            action="remove"
            :applied-labels="appliedLabelsForSelection"
            @remove="onRemoveLabels"
          />
        </div>
      </div>
    </div>
  </Transition>
</template>
