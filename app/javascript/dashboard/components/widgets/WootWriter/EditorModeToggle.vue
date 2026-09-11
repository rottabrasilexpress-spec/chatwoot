<script setup>
import { computed, useTemplateRef } from 'vue';
import { useElementSize } from '@vueuse/core';
import { REPLY_EDITOR_MODES } from './constants';

const props = defineProps({
  mode: {
    type: String,
    default: REPLY_EDITOR_MODES.REPLY,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  isReplyRestricted: {
    type: Boolean,
    default: false,
  },
  showConversationAi: {
    type: Boolean,
    default: false,
  },
  conversationAiActive: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['setReplyMode', 'openConversationAi']);

const wootEditorReplyMode = useTemplateRef('wootEditorReplyMode');
const wootEditorPrivateMode = useTemplateRef('wootEditorPrivateMode');
const wootEditorConversationAiMode = useTemplateRef(
  'wootEditorConversationAiMode'
);

const replyModeSize = useElementSize(wootEditorReplyMode);
const privateModeSize = useElementSize(wootEditorPrivateMode);
const conversationAiModeSize = useElementSize(wootEditorConversationAiMode);

/**
 * Computed boolean indicating if the editor is in private note mode
 * When isReplyRestricted is true, force switch to private note
 * Otherwise, respect the current mode prop
 * @type {ComputedRef<boolean>}
 */
const isPrivate = computed(() => {
  if (props.isReplyRestricted) {
    // Force switch to private note when replies are restricted
    return true;
  }
  // Otherwise respect the current mode
  return props.mode === REPLY_EDITOR_MODES.NOTE;
});

const activeModeSize = computed(() => {
  if (props.conversationAiActive) return conversationAiModeSize.width.value;
  if (isPrivate.value) return privateModeSize.width.value;
  return replyModeSize.width.value;
});

/**
 * Computes the width of the sliding background chip in pixels
 * Includes 16px of padding in the calculation
 * @type {ComputedRef<string>}
 */
const width = computed(() => {
  const widthWithPadding = activeModeSize.value + 16;
  return `${widthWithPadding}px`;
});

/**
 * Computes the X translation value for the sliding background chip
 * Translates by the width of reply mode + padding when in private mode
 * @type {ComputedRef<string>}
 */
const translateValue = computed(() => {
  let xTranslate = 0;
  if (props.conversationAiActive) {
    xTranslate = replyModeSize.width.value + privateModeSize.width.value + 32;
  } else if (isPrivate.value) {
    xTranslate = replyModeSize.width.value + 16;
  }

  return `${xTranslate}px`;
});

const selectMode = mode => {
  emit('setReplyMode', mode);
};
</script>

<template>
  <div
    role="group"
    :aria-disabled="disabled || isReplyRestricted"
    class="flex items-center w-auto h-8 p-1 transition-all border rounded-full bg-n-alpha-2 group relative duration-300 ease-in-out z-0 active:scale-[0.995] active:duration-75"
    :class="{
      'cursor-not-allowed': disabled || isReplyRestricted,
    }"
  >
    <button
      ref="wootEditorReplyMode"
      type="button"
      data-reply-mode
      class="flex items-center gap-1 px-2 z-20 border-0 bg-transparent"
      :disabled="disabled || isReplyRestricted"
      :aria-pressed="!isPrivate && !conversationAiActive"
      @click.stop="selectMode(REPLY_EDITOR_MODES.REPLY)"
    >
      {{ $t('CONVERSATION.REPLYBOX.REPLY') }}
    </button>
    <button
      ref="wootEditorPrivateMode"
      type="button"
      data-private-note-mode
      class="flex items-center gap-1 px-2 z-20 border-0 bg-transparent"
      :disabled="disabled || isReplyRestricted"
      :aria-pressed="isPrivate && !conversationAiActive"
      @click.stop="selectMode(REPLY_EDITOR_MODES.NOTE)"
    >
      {{ $t('CONVERSATION.REPLYBOX.PRIVATE_NOTE') }}
    </button>
    <button
      v-if="showConversationAi"
      ref="wootEditorConversationAiMode"
      type="button"
      data-conversation-ai-toggle
      class="flex items-center gap-1 px-2 z-20 text-n-violet-9 border-0 bg-transparent"
      :disabled="disabled || isReplyRestricted"
      :aria-pressed="conversationAiActive"
      :title="$t('CONVERSATION.REPLYBOX.CONVERSATION_AI_HELPER')"
      @click.stop="$emit('openConversationAi')"
    >
      {{ $t('CONVERSATION.REPLYBOX.CONVERSATION_AI') }}
    </button>
    <div
      aria-hidden="true"
      class="absolute shadow-sm rounded-full h-6 w-[var(--chip-width)] ease-in-out translate-x-[var(--translate-x)] rtl:translate-x-[var(--rtl-translate-x)] bg-n-solid-1"
      :class="{
        'transition-all duration-300': !disabled && !isReplyRestricted,
      }"
      :style="{
        '--chip-width': width,
        '--translate-x': translateValue,
        '--rtl-translate-x': `calc(-1 * var(--translate-x))`,
      }"
    />
  </div>
</template>
