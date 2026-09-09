<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { downloadFile } from '@chatwoot/utils';
import {
  MEDIA_TYPES,
  NON_FILE_TYPES,
} from 'dashboard/components-next/message/constants';
import { parseAttachmentDragData } from './attachmentDrag';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';
import Media from 'dashboard/components-next/SharedAttachments/Media.vue';
import Files from 'dashboard/components-next/SharedAttachments/Files.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const MEDIA_PEEK_LIMIT = 6;
const FILES_PEEK_LIMIT = 3;

const allAttachments = useMapGetter('getSelectedChatAttachments');
const attachmentsLoaded = useMapGetter('getSelectedChatAttachmentsLoaded');
const { t } = useI18n();

const mediaAttachments = computed(() =>
  allAttachments.value
    .filter(a => MEDIA_TYPES.includes(a.file_type) && a.data_url)
    .sort((a, b) => (b.created_at || 0) - (a.created_at || 0))
);

const hasContent = computed(() =>
  allAttachments.value.some(
    a => a.data_url && !NON_FILE_TYPES.includes(a.file_type)
  )
);

const showGallery = ref(false);
const selectedAttachment = ref(null);
const isDropActive = ref(false);
const saveState = ref('idle');

const dropHint = 'Arraste anexos recebidos aqui para baixá-los com segurança';
const saveErrorMessage = 'Não foi possível salvar o anexo recebido.';

const saveStateMessage = computed(() => {
  if (saveState.value === 'saving') return 'Salvando anexo…';
  if (saveState.value === 'success') return 'Anexo salvo.';
  if (saveState.value === 'error') return 'Não foi possível salvar.';
  return dropHint;
});

const fileExtension = fileName => {
  const extension = fileName?.split('.').pop();
  return extension && extension !== fileName ? extension : undefined;
};

const findAttachment = id =>
  allAttachments.value.find(attachment => String(attachment.id) === String(id));

const getDroppedAttachments = event => {
  const droppedAttachment = parseAttachmentDragData(event.dataTransfer);
  if (droppedAttachment) {
    const attachment = findAttachment(droppedAttachment.id);
    return attachment?.data_url ? [{ type: 'conversation', attachment }] : [];
  }

  return Array.from(event.dataTransfer?.files || [])
    .filter(file => file.size > 0)
    .map(file => ({ type: 'file', file }));
};

const saveDroppedAttachment = async droppedAttachment => {
  if (droppedAttachment.type === 'conversation') {
    const {
      data_url: url,
      file_type: type,
      extension,
    } = droppedAttachment.attachment;
    await downloadFile({ url, type, extension });
    return;
  }

  const { file } = droppedAttachment;
  const url = URL.createObjectURL(file);
  try {
    await downloadFile({
      url,
      type: file.type,
      extension: fileExtension(file.name),
    });
  } finally {
    URL.revokeObjectURL(url);
  }
};

const onDragEnter = () => {
  isDropActive.value = true;
};

const onDragLeave = () => {
  isDropActive.value = false;
};

const onDrop = async event => {
  isDropActive.value = false;
  const droppedAttachments = getDroppedAttachments(event);

  if (!droppedAttachments.length) {
    saveState.value = 'error';
    useAlert(saveErrorMessage);
    return;
  }

  saveState.value = 'saving';
  try {
    // This action only downloads existing attachments or dropped local files.
    // It intentionally does not dispatch a message or mutate conversation data.
    await Promise.all(droppedAttachments.map(saveDroppedAttachment));
    saveState.value = 'success';
  } catch (error) {
    saveState.value = 'error';
    useAlert(error.message || saveErrorMessage);
  }
};

const onMediaSelect = attachment => {
  selectedAttachment.value = attachment;
  showGallery.value = true;
};

const onFileSelect = attachment => {
  if (attachment.data_url) {
    window.open(attachment.data_url, '_blank', 'noopener,noreferrer');
  }
};
</script>

<template>
  <div
    data-testid="attachments-dropzone"
    class="p-2 transition-colors rounded-lg"
    :class="{ 'bg-n-blue-2 ring-1 ring-n-blue-7': isDropActive }"
    @dragenter.prevent="onDragEnter"
    @dragover.prevent="onDragEnter"
    @dragleave.prevent="onDragLeave"
    @drop.prevent="onDrop"
  >
    <div
      class="flex items-center gap-2 px-3 py-2 mb-3 text-xs border border-dashed rounded-lg text-n-slate-11 border-n-strong"
      :class="{ 'text-n-blue-11 border-n-blue-7': isDropActive }"
      aria-live="polite"
    >
      <span class="i-lucide-download size-4 shrink-0" aria-hidden="true" />
      <span>{{ saveStateMessage }}</span>
    </div>
    <div v-if="!attachmentsLoaded" class="flex justify-center p-3">
      <Spinner class="size-5" />
    </div>
    <p v-else-if="!hasContent" class="p-3 text-sm text-center text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.SHARED_FILES.EMPTY') }}
    </p>
    <div v-else class="flex flex-col gap-5">
      <Media
        :attachments="allAttachments"
        :peek-limit="MEDIA_PEEK_LIMIT"
        @select="onMediaSelect"
      />
      <Files
        :attachments="allAttachments"
        :peek-limit="FILES_PEEK_LIMIT"
        @select="onFileSelect"
      />
    </div>
    <GalleryView
      v-if="showGallery && selectedAttachment"
      v-model:show="showGallery"
      :attachment="selectedAttachment"
      :all-attachments="mediaAttachments"
      auto-play
      @close="showGallery = false"
    />
  </div>
</template>
