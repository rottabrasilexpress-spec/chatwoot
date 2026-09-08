<script setup>
import { computed } from 'vue';
import { useMessageContext } from '../../provider.js';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { MESSAGE_VARIANTS } from '../../constants';

const props = defineProps({
  content: {
    type: String,
    required: true,
  },
});

const { variant } = useMessageContext();

const formattedContent = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.ACTIVITY) {
    return props.content;
  }

  return new MessageFormatter(props.content).formattedMessage;
});
</script>

<template>
  <span v-dompurify-html="formattedContent" class="prose prose-bubble" />
</template>

<style scoped>
.prose-bubble :deep(.prosemirror-mention-node) {
  display: inline-block;
  padding: 0 0.25rem;
  color: rgb(var(--blue-11));
  font-weight: 650;
  background: color-mix(in srgb, rgb(var(--blue-3)) 72%, transparent);
  border-radius: 0.35rem;
}

.dark .prose-bubble :deep(.prosemirror-mention-node) {
  color: rgb(var(--blue-12));
  background: color-mix(in srgb, rgb(var(--blue-9)) 28%, transparent);
}
</style>
