<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ConversationAiStatus from './ConversationAiStatus.vue';
import PickupContactName from 'dashboard/components-next/Conversation/Pickups/PickupContactName.vue';
import PickupScheduleDates from 'dashboard/components-next/Conversation/Pickups/PickupScheduleDates.vue';
import {
  CLOSED_PICKUP_LABEL,
  PICKUP_SUFFIX_KEY,
} from 'dashboard/helper/rottaPickup';
import { editPickupDates } from 'dashboard/composables/useRottaPickupDialog';
import ConversationCallButton from './ConversationCallButton.vue';
import FollowingButton from 'dashboard/components-next/Conversation/Review/FollowingButton.vue';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { getOriginalAvatarUrl } from 'dashboard/helper/avatarUrl';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox } = useInbox();
const { updateUISettings } = useUISettings();

const currentChat = computed(() => store.getters.getSelectedChat);
const closedPickup = computed(
  () => currentChat.value?.labels?.includes(CLOSED_PICKUP_LABEL) === true
);
const editPickupDate = () => editPickupDates(currentChat.value.id, store);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_participating: 'participating',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const currentContactAvatarUrl = computed(() =>
  getOriginalAvatarUrl(
    currentContact.value?.avatar_url || currentContact.value?.thumbnail
  )
);
const openContactProfile = () => {
  updateUISettings({
    is_contact_sidebar_open: true,
    is_copilot_panel_open: false,
  });
};

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const hasSlaPolicyId = computed(
  () => props.chat?.applied_sla?.id && !currentContact.value?.blocked
);

const hasKelvinCaioLabel = computed(() =>
  props.chat?.labels?.includes('kelvin-caio')
);

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(props.chat.id));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex flex-col gap-3 items-center justify-between flex-1 w-full min-w-0 xl:flex-row px-3 pt-3 pb-2 min-h-24 xl:min-h-12"
    :class="{ 'rotta-kelvin-header': hasKelvinCaioLabel }"
  >
    <div
      class="flex items-center justify-start w-full xl:w-auto max-w-full min-w-0 xl:flex-1"
    >
      <BackButton
        v-if="showBackButton"
        :back-url="backButtonUrl"
        class="me-2"
      />
      <button
        type="button"
        class="rotta-header-avatar-button"
        :aria-label="$t('CONVERSATION.SIDEBAR.CONTACT')"
        :title="$t('CONVERSATION.SIDEBAR.CONTACT')"
        @click="openContactProfile"
      >
        <Avatar
          :name="currentContact.name"
          :src="currentContactAvatarUrl"
          :size="44"
          :status="currentContact.availability_status"
          rounded-full
          class="rounded-full"
          hide-offline-status
        />
      </button>
      <div class="flex flex-col items-start min-w-0 ms-2 overflow-hidden">
        <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
          <span
            class="text-sm font-medium truncate leading-tight text-n-slate-12"
          >
            <PickupContactName
              :name="currentContact.name"
              :suffix="currentContact.custom_attributes?.[PICKUP_SUFFIX_KEY]"
              :allow-legacy="closedPickup"
              :show-date="!closedPickup"
            />
          </span>
          <ConversationAiStatus
            v-if="currentChat?.id"
            :conversation-id="currentChat.id"
            density="header"
          />
          <button
            v-if="closedPickup"
            type="button"
            :aria-label="$t('ROTTA_PICKUP.EDIT_DATES')"
            :title="$t('ROTTA_PICKUP.EDIT_DATES')"
            class="grid size-7 shrink-0 place-items-center rounded-md text-n-amber-11 hover:bg-n-amber-3"
            @click="editPickupDate"
          >
            <span class="i-lucide-calendar-days size-4" aria-hidden="true" />
          </button>
          <fluent-icon
            v-if="!isHMACVerified"
            v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
            size="14"
            class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
            icon="warning"
          />
        </div>

        <div
          class="flex items-center gap-1 overflow-hidden text-xs conversation--header--actions text-n-slate-11 text-ellipsis whitespace-nowrap"
        >
          <button
            type="button"
            class="truncate text-label-small text-n-slate-11 hover:text-n-slate-12 !p-0 cucursor-pointer"
            @click="copyConversationId"
          >
            {{ `#${chat.id}` }}
          </button>
          <span v-if="hasMultipleInboxes" aria-hidden="true">{{
            '\u2022'
          }}</span>
          <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
          <span v-if="isSnoozed">•</span>
          <span v-if="isSnoozed" class="font-medium text-n-amber-10">
            {{ snoozedDisplayText }}
          </span>
        </div>
        <PickupScheduleDates
          v-if="closedPickup"
          :name="currentContact.name"
          :suffix="currentContact.custom_attributes?.[PICKUP_SUFFIX_KEY]"
          :schedule="currentChat.rotta_pickup"
          class="mt-1"
        />
      </div>
    </div>
    <div
      class="flex flex-row flex-wrap items-center justify-start xl:justify-end flex-shrink-0 gap-2 w-full xl:w-auto header-actions-wrap"
    >
      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="hidden md:flex"
      />
      <ConversationCallButton :inbox="inbox" :chat="currentChat" />
      <FollowingButton v-if="chat.id" :conversation-id="chat.id" />
      <MoreActions :conversation-id="currentChat.id" />
    </div>
  </div>
</template>

<style scoped>
.rotta-header-avatar-button {
  flex: 0 0 auto;
  padding: 0;
  background: transparent;
  border: 0;
  border-radius: 999px;
  cursor: pointer;
}

.rotta-header-avatar-button:focus-visible {
  outline: 2px solid var(--color-n-brand, #2563eb);
  outline-offset: 3px;
}

.rotta-kelvin-header {
  box-shadow: inset 0 -2px 0 #c026d3;
}
</style>
