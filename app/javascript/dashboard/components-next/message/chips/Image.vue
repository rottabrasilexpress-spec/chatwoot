<script setup>
import { computed, ref } from 'vue';
import Icon from 'next/icon/Icon.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

const props = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});
const hasError = ref(false);
const showGallery = ref(false);

const { filteredCurrentChatAttachments } = useMessageContext();

const imageStyle = computed(() => {
  const { width, height } = props.attachment;
  if (width && height) return { aspectRatio: `${width} / ${height}` };
  return undefined;
});

const handleError = () => {
  hasError.value = true;
};
</script>

<template>
  <div
    class="rotta-media-image overflow-hidden max-w-full rounded-lg cursor-pointer"
    :style="imageStyle"
    @click="showGallery = true"
  >
    <div
      v-if="hasError"
      class="flex flex-col items-center justify-center gap-1 text-xs text-center rounded-lg size-full bg-n-alpha-1 text-n-slate-11"
    >
      <Icon icon="i-lucide-circle-off" class="text-n-slate-11" />
      {{ $t('COMPONENTS.MEDIA.LOADING_FAILED') }}
    </div>
    <img
      v-else
      class="block max-w-full max-h-80 w-auto h-auto object-contain skip-context-menu"
      :src="attachment.dataUrl"
      :alt="attachment.fallbackTitle || 'Imagem recebida'"
      loading="lazy"
      decoding="async"
      @error="handleError"
    />
  </div>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="handleError"
    @close="() => (showGallery = false)"
  />
</template>

<style scoped>
.rotta-media-image {
  width: min(20rem, 100%);
  max-height: 20rem;
  background: rgb(0 0 0 / 4%);
}

.rotta-media-image img {
  min-width: 8rem;
  min-height: 6rem;
}
</style>
