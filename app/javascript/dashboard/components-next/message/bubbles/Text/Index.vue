<script setup>
import { computed, ref } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';
import { getMessageDisplayContent } from '../../helpers/messageContent';
import { useI18n } from 'vue-i18n';

const { content, attachments, contentAttributes, messageType } =
  useMessageContext();
const { t } = useI18n();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const isDeletedMessage = computed(() => contentAttributes.value?.deleted);
const deletedMessageLabel = computed(() => {
  const deletedBy =
    contentAttributes.value?.deletedBy || contentAttributes.value?.deleted_by;
  return deletedBy === 'customer'
    ? t('CONVERSATION.DELETED_MESSAGE_BY_CUSTOMER')
    : t('CONVERSATION.DELETED_MESSAGE');
});

const renderContent = computed(() => {
  if (isDeletedMessage.value) return deletedMessageLabel.value;

  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const displayedContent = computed(() =>
  getMessageDisplayContent(renderContent.value, attachments.value)
);

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !displayedContent.value && !attachments.value?.length;
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble
    class="px-4 py-3"
    :class="{ 'rotta-deleted-message': isDeletedMessage }"
    data-bubble-name="text"
  >
    <div class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="displayedContent" :content="displayedContent" />
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style scoped>
p:last-child {
  margin-bottom: 0;
}

.rotta-deleted-message {
  color: #dc2626 !important;
  font-weight: 600;
}

.rotta-deleted-message :deep(*) {
  color: inherit !important;
}
</style>
