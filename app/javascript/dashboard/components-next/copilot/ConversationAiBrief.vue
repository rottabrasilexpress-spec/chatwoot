<script setup>
import { computed, ref, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  brief: { type: Object, required: true },
  conversationId: { type: [Number, String], required: true },
});

const draft = ref('');
const used = ref(false);
watch(
  () => props.brief.version,
  () => {
    draft.value = props.brief.result?.draft || '';
    used.value = false;
  },
  { immediate: true }
);

const hasPlaceholders = computed(() => /\[[^\]\n]+\]/.test(draft.value));

const approveDraft = () => {
  if (used.value || hasPlaceholders.value || !draft.value.trim()) return;
  emitter.emit(BUS_EVENTS.INSERT_CONVERSATION_AI_BRIEF_DRAFT, {
    conversationId: props.conversationId,
    text: draft.value.trim(),
    onInserted: () => {
      used.value = true;
    },
  });
};
</script>

<template>
  <section
    class="flex w-full flex-col gap-3 rounded-xl border border-n-weak bg-n-surface-1 p-3 text-n-slate-12"
  >
    <h3 class="m-0 text-sm font-semibold">
      {{ $t('CONVERSATION.AUTOMATIC_BRIEF.TITLE') }}
    </h3>
    <p v-if="brief.state === 'failed'" role="status" class="m-0 text-n-ruby-11">
      {{ $t('CONVERSATION.AUTOMATIC_BRIEF.ERROR') }}
    </p>
    <template v-else>
      <div
        v-for="(topic, index) in brief.result.topics"
        :key="index"
        class="grid gap-2 rounded-lg border border-n-weak p-2"
      >
        <div class="rounded-md bg-n-blue-2 px-2 py-1.5">
          <p class="m-0 text-xs font-semibold text-n-blue-11">
            {{ $t('CONVERSATION.AUTOMATIC_BRIEF.REQUEST') }}
          </p>
          <p class="m-0 break-words">{{ topic.request }}</p>
        </div>
        <div class="rounded-md bg-n-teal-2 px-2 py-1.5">
          <p class="m-0 text-xs font-semibold text-n-teal-11">
            {{ $t('CONVERSATION.AUTOMATIC_BRIEF.NEXT_STEP') }}
          </p>
          <p class="m-0 break-words">{{ topic.answer }}</p>
        </div>
      </div>
      <label class="flex flex-col gap-1 text-xs font-semibold">
        {{ $t('CONVERSATION.COPILOT.SUGGESTED_REPLY') }}
        <textarea
          v-model="draft"
          rows="4"
          class="w-full resize-y rounded-lg border border-n-strong bg-n-surface-1 p-2 text-sm font-normal text-n-slate-12"
          @input="used = false"
        />
      </label>
      <p v-if="hasPlaceholders" class="m-0 text-xs text-n-amber-11">
        {{ $t('CONVERSATION.AUTOMATIC_BRIEF.FILL_PLACEHOLDERS') }}
      </p>
      <div class="flex items-center gap-2">
        <Button
          :label="$t('CONVERSATION.AUTOMATIC_BRIEF.APPROVE')"
          :disabled="hasPlaceholders || !draft.trim() || used"
          sm
          @click="approveDraft"
        />
        <span v-if="used" role="status" class="text-xs text-n-teal-11">
          {{ $t('CONVERSATION.AUTOMATIC_BRIEF.INSERTED') }}
        </span>
      </div>
    </template>
  </section>
</template>
