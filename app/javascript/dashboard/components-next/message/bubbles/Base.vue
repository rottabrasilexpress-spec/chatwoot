<script setup>
import { computed } from 'vue';

import MessageMeta from '../MessageMeta.vue';
import CaptainGenerationDetails from '../CaptainGenerationDetails.vue';

import { emitter } from 'shared/helpers/mitt';
import { useMessageContext } from '../provider.js';
import { useI18n } from 'vue-i18n';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { MESSAGE_VARIANTS, ORIENTATION, SENDER_TYPES } from '../constants';

const props = defineProps({
  hideMeta: { type: Boolean, default: false },
});

const {
  variant,
  orientation,
  inReplyTo,
  shouldGroupWithNext,
  id,
  sender,
  senderType,
  contentAttributes,
  starred,
} = useMessageContext();
const { t } = useI18n();

const isCaptainMessage = computed(
  () =>
    (sender.value?.type ?? senderType.value) === SENDER_TYPES.CAPTAIN_ASSISTANT
);

const metaColorClass = computed(() =>
  variant.value === MESSAGE_VARIANTS.PRIVATE
    ? 'text-n-amber-12/50'
    : 'text-n-slate-11'
);

const emailMetaClass = computed(() =>
  variant.value === MESSAGE_VARIANTS.EMAIL ? 'px-3 pb-3' : ''
);

const varaintBaseMap = {
  [MESSAGE_VARIANTS.AGENT]: 'bg-n-solid-blue text-n-slate-12',
  [MESSAGE_VARIANTS.PRIVATE]:
    'bg-n-solid-amber text-n-amber-12 [&_.prosemirror-mention-node]:font-semibold',
  [MESSAGE_VARIANTS.USER]: 'bg-n-slate-4 text-n-slate-12',
  [MESSAGE_VARIANTS.ACTIVITY]: 'bg-n-alpha-1 text-n-slate-11 text-sm',
  [MESSAGE_VARIANTS.BOT]: 'bg-n-solid-iris text-n-slate-12',
  [MESSAGE_VARIANTS.TEMPLATE]: 'bg-n-solid-iris text-n-slate-12',
  [MESSAGE_VARIANTS.ERROR]: 'bg-n-ruby-4 text-n-ruby-12',
  [MESSAGE_VARIANTS.EMAIL]: 'w-full',
  [MESSAGE_VARIANTS.UNSUPPORTED]:
    'bg-n-solid-amber/70 border border-dashed border-n-amber-12 text-n-amber-12',
};

const orientationMap = {
  [ORIENTATION.LEFT]:
    'left-bubble rounded-xl ltr:rounded-bl-sm rtl:rounded-br-sm',
  [ORIENTATION.RIGHT]:
    'right-bubble rounded-xl ltr:rounded-br-sm rtl:rounded-bl-sm',
  [ORIENTATION.CENTER]: 'rounded-md',
};

const flexOrientationClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'justify-start',
    [ORIENTATION.RIGHT]: 'justify-end',
    [ORIENTATION.CENTER]: 'justify-center',
  };

  return map[orientation.value];
});

const messageClass = computed(() => {
  const classToApply = [varaintBaseMap[variant.value]];

  if (variant.value === MESSAGE_VARIANTS.USER) {
    classToApply.push('rotta-bubble-incoming');
  } else if (
    [
      MESSAGE_VARIANTS.AGENT,
      MESSAGE_VARIANTS.BOT,
      MESSAGE_VARIANTS.TEMPLATE,
    ].includes(variant.value)
  ) {
    classToApply.push('rotta-bubble-outgoing');
  }

  if (variant.value !== MESSAGE_VARIANTS.ACTIVITY) {
    classToApply.push(orientationMap[orientation.value]);
  } else {
    classToApply.push('rounded-lg');
  }

  return classToApply;
});

const scrollToMessage = () => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
    messageId: inReplyTo.value.id,
  });
};

const shouldShowMeta = computed(
  () =>
    !props.hideMeta &&
    !shouldGroupWithNext.value &&
    variant.value !== MESSAGE_VARIANTS.ACTIVITY
);

const replyToPreview = computed(() => {
  if (!inReplyTo.value) return '';

  const { content, attachments } = inReplyTo.value;

  if (content) return new MessageFormatter(content).formattedMessage;
  if (attachments?.length) {
    const firstAttachment = attachments[0];
    const fileType = firstAttachment.fileType ?? firstAttachment.file_type;

    return t(`CHAT_LIST.ATTACHMENTS.${fileType}.CONTENT`);
  }

  return t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND');
});

const replyToSenderName = computed(() => {
  const replyMessage = inReplyTo.value;
  const replySender = replyMessage?.sender || {};

  return (
    replySender.name ||
    replyMessage?.sender_name ||
    replyMessage?.senderName ||
    t('CONVERSATION.CONTACT')
  );
});
</script>

<template>
  <div
    class="text-sm min-w-0"
    :class="[
      messageClass,
      {
        'max-w-lg': variant !== MESSAGE_VARIANTS.EMAIL,
      },
    ]"
  >
    <div
      v-if="inReplyTo"
      class="rotta-reply-preview p-2 -mx-1 mb-2 rounded-lg cursor-pointer bg-n-alpha-black1"
      @click="scrollToMessage"
    >
      <div class="rotta-reply-author truncate">{{ replyToSenderName }}</div>
      <div
        v-dompurify-html="replyToPreview"
        class="prose prose-bubble line-clamp-2"
      />
    </div>
    <slot />
    <div
      v-if="contentAttributes?.rottaForwarded"
      class="rotta-message-forwarded"
    >
      {{ t('CONVERSATION.CONTEXT_MENU.FORWARDED_LABEL') }}
    </div>
    <div v-if="contentAttributes?.edited" class="rotta-message-forwarded">
      {{ t('CONVERSATION.CONTEXT_MENU.EDITED_LABEL') }}
    </div>
    <div
      v-if="
        contentAttributes?.rottaReaction ||
        contentAttributes?.rottaPinned ||
        starred
      "
      class="rotta-message-markers"
    >
      <span
        v-if="contentAttributes?.rottaReaction"
        class="rotta-message-reaction"
        :title="t('CONVERSATION.CONTEXT_MENU.REACTION')"
      >
        {{ contentAttributes.rottaReaction }}
      </span>
      <span
        v-if="contentAttributes?.rottaPinned"
        class="rotta-message-marker"
        :title="t('CONVERSATION.CONTEXT_MENU.PINNED')"
      >
        <span class="i-lucide-pin size-3" />
      </span>
      <span
        v-if="starred"
        class="rotta-message-marker rotta-message-marker--star"
        :title="t('CONVERSATION.CONTEXT_MENU.STARRED')"
      >
        <span class="i-lucide-star size-3" />
      </span>
    </div>
    <template v-if="shouldShowMeta">
      <CaptainGenerationDetails
        v-if="isCaptainMessage"
        :message-id="id"
        class="mt-2"
      >
        <template #meta>
          <MessageMeta :class="[emailMetaClass, metaColorClass]" />
        </template>
      </CaptainGenerationDetails>
      <MessageMeta
        v-else
        :class="[flexOrientationClass, emailMetaClass, metaColorClass]"
        class="mt-2"
      />
    </template>
  </div>
</template>

<style scoped>
.rotta-reply-preview {
  box-shadow: inset 3px 0 0 rgb(var(--blue-9));
}

.rotta-reply-author {
  color: rgb(var(--blue-9));
  font-size: 0.75rem;
  font-weight: 650;
  line-height: 1.25rem;
}

.rotta-message-forwarded {
  @apply mt-1 text-xs italic text-n-slate-10;
}

.rotta-message-markers {
  @apply mt-1 flex items-center gap-1;
}

.rotta-message-reaction,
.rotta-message-marker {
  @apply inline-flex h-5 min-w-5 items-center justify-center rounded-full border border-n-strong bg-n-surface-1 px-1 text-xs shadow-sm;
}

.rotta-message-marker {
  @apply text-n-slate-10;
}

.rotta-message-marker--star {
  @apply text-n-amber-10;
}
</style>
