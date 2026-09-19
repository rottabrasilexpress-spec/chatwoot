<script setup>
import { computed } from 'vue';
import { formatBytes } from 'shared/helpers/FileHelper';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  attachments: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['removeAttachment']);

const nonRecordedAudioAttachments = computed(() => {
  return props.attachments.filter(attachment => !attachment?.isVoiceMessage);
});

const recordedAudioAttachments = computed(() =>
  props.attachments.filter(attachment => attachment.isVoiceMessage)
);

const onRemoveAttachment = itemIndex => {
  emit(
    'removeAttachment',
    nonRecordedAudioAttachments.value
      .filter((_, index) => index !== itemIndex)
      .concat(recordedAudioAttachments.value)
  );
};

const formatFileSize = file => {
  const size = file.byte_size || file.size;
  return formatBytes(size, 0);
};

const isTypeImage = file => {
  const type = file.content_type || file.type;
  return type.includes('image');
};

const fileName = file => {
  return file.filename || file.name;
};
</script>

<template>
  <div class="flex flex-wrap gap-y-1 gap-x-2 overflow-auto max-h-[12.5rem]">
    <div
      v-for="(attachment, index) in nonRecordedAudioAttachments"
      :key="attachment.id"
      class="flex items-center gap-2 p-2 rounded-lg bg-n-slate-3 w-[min(100%,20rem)]"
      :title="fileName(attachment.resource)"
    >
      <div class="flex items-center flex-shrink-0 w-9">
        <img
          v-if="isTypeImage(attachment.resource)"
          class="object-cover w-9 h-9 rounded-md"
          :src="attachment.thumb"
          :alt="`Pré-visualização de ${fileName(attachment.resource)}`"
        />
        <span
          v-else
          class="relative w-9 h-9 text-lg text-left -top-px"
          aria-hidden="true"
        >
          📄
        </span>
      </div>
      <div class="flex-1 min-w-0 overflow-hidden text-ellipsis">
        <span
          class="block overflow-hidden text-sm font-medium text-ellipsis whitespace-nowrap"
        >
          {{ fileName(attachment.resource) }}
        </span>
        <span class="block mt-0.5 text-xs text-n-slate-10">
          {{ formatFileSize(attachment.resource) }}
        </span>
      </div>
      <div class="flex items-center justify-center">
        <Button
          ghost
          slate
          xs
          icon="i-lucide-x"
          :aria-label="`Remover ${fileName(attachment.resource)}`"
          @click="onRemoveAttachment(index)"
        />
      </div>
    </div>
  </div>
</template>
