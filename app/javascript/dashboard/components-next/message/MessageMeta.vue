<script setup>
import { computed } from 'vue';
import { whatsappMessageTimestamp } from 'shared/helpers/timeHelper';

import MessageStatus from './MessageStatus.vue';
import Icon from 'next/icon/Icon.vue';
import { useInbox } from 'dashboard/composables/useInbox';
import { useMessageContext } from './provider.js';

import { MESSAGE_STATUS, MESSAGE_TYPES } from './constants';
import { getMessageDeliveryStatus } from 'dashboard/helper/messageStatus';

const {
  isAFacebookInbox,
  isALineChannel,
  isAPIInbox,
  isASmsInbox,
  isATelegramChannel,
  isATwilioChannel,
  isAWebWidgetInbox,
  isAWhatsAppChannel,
  isAnEmailChannel,
  isAnInstagramChannel,
  isATiktokChannel,
} = useInbox();

const {
  status,
  isPrivate,
  createdAt,
  sourceId,
  messageType,
  contentAttributes,
  additionalAttributes,
} = useMessageContext();

const readableTime = computed(() => whatsappMessageTimestamp(createdAt.value));

const providerStatus = computed(() => {
  return getMessageDeliveryStatus({
    status: status.value,
    additional_attributes: additionalAttributes.value,
    content_attributes: contentAttributes.value,
  });
});

const effectiveStatus = computed(() => {
  return providerStatus.value || status.value;
});

const showStatusIndicator = computed(() => {
  if (isPrivate.value) return false;
  // Don't show status for failed messages, we already show error message
  if (effectiveStatus.value === MESSAGE_STATUS.FAILED) return false;
  // Don't show status for deleted messages
  if (contentAttributes.value?.deleted) return false;

  if (messageType.value === MESSAGE_TYPES.OUTGOING) return true;
  if (messageType.value === MESSAGE_TYPES.TEMPLATE) return true;

  return false;
});

const isSent = computed(() => {
  if (!showStatusIndicator.value) return false;

  // Messages will be marked as sent for the Email channel if they have a source ID.
  if (isAnEmailChannel.value) return !!sourceId.value;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isAFacebookInbox.value ||
    isASmsInbox.value ||
    isATelegramChannel.value ||
    isAnInstagramChannel.value ||
    isATiktokChannel.value
  ) {
    // Uazapi-created messages may not have source_id yet. The Chatwoot
    // message status is still authoritative for the first (sent) tick.
    return effectiveStatus.value === MESSAGE_STATUS.SENT;
  }

  // API inbox messages use real sent/delivered/read status values from the external system.
  if (isAPIInbox.value) return effectiveStatus.value === MESSAGE_STATUS.SENT;

  // All messages will be mark as sent for the Line channel, as there is no source ID.
  if (isALineChannel.value) return true;

  // Uazapi is connected through a custom/API inbox in this installation.
  // Keep the first tick visible even when the channel does not identify
  // itself as one of Chatwoot's built-in WhatsApp channel types.
  return effectiveStatus.value === MESSAGE_STATUS.SENT;
});

const isDelivered = computed(() => {
  if (!showStatusIndicator.value) return false;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isASmsInbox.value ||
    isAFacebookInbox.value ||
    isAnInstagramChannel.value ||
    isATiktokChannel.value
  ) {
    return effectiveStatus.value === MESSAGE_STATUS.DELIVERED;
  }
  // API inbox messages use real delivered status from the external system.
  if (isAPIInbox.value)
    return effectiveStatus.value === MESSAGE_STATUS.DELIVERED;
  // All messages marked as delivered for the web widget inbox once they are sent.
  if (isAWebWidgetInbox.value) {
    return effectiveStatus.value === MESSAGE_STATUS.SENT;
  }
  if (isALineChannel.value) {
    return effectiveStatus.value === MESSAGE_STATUS.DELIVERED;
  }

  return effectiveStatus.value === MESSAGE_STATUS.DELIVERED;
});

const isRead = computed(() => {
  if (!showStatusIndicator.value) return false;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isAFacebookInbox.value ||
    isAnInstagramChannel.value ||
    isATiktokChannel.value
  ) {
    return effectiveStatus.value === MESSAGE_STATUS.READ;
  }

  if (isAWebWidgetInbox.value || isAPIInbox.value) {
    return effectiveStatus.value === MESSAGE_STATUS.READ;
  }

  return effectiveStatus.value === MESSAGE_STATUS.READ;
});

const statusToShow = computed(() => {
  if (isRead.value) return MESSAGE_STATUS.READ;
  if (isDelivered.value) return MESSAGE_STATUS.DELIVERED;
  if (isSent.value) return MESSAGE_STATUS.SENT;

  return MESSAGE_STATUS.PROGRESS;
});
</script>

<template>
  <div class="text-xs flex items-center gap-1.5">
    <div class="inline">
      <time class="inline">{{ readableTime }}</time>
    </div>
    <Icon v-if="isPrivate" icon="i-lucide-lock-keyhole" class="size-3" />
    <MessageStatus v-if="showStatusIndicator" :status="statusToShow" />
  </div>
</template>
`
