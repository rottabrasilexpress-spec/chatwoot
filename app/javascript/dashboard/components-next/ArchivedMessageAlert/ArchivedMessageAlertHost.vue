<script setup>
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const router = useRouter();
const store = useStore();
const { accountId } = useAccount();
const alerts = useMapGetter('archivedMessageAlerts/getAlerts');

const dismiss = alertId => {
  store.dispatch('archivedMessageAlerts/dismiss', alertId);
};

const openConversation = alert => {
  dismiss(alert.alert_id);
  router.push({
    name: 'archived_conversation',
    params: {
      accountId: accountId.value,
      conversationId: alert.conversation_id,
    },
  });
};
</script>

<template>
  <div
    v-show="alerts.length"
    class="fixed ltr:right-4 rtl:left-4 bottom-4 z-[60] flex w-[min(25rem,calc(100vw-2rem))] flex-col gap-3"
    data-test-id="archived-message-alert-host"
    aria-live="assertive"
  >
    <article
      v-for="alert in alerts"
      :key="alert.alert_id"
      class="rounded-2xl border-2 border-n-amber-9 bg-n-solid-1 p-4 shadow-2xl outline outline-4 outline-n-amber-9/20"
      role="alert"
      data-test-id="archived-message-alert"
    >
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <p class="text-xs font-bold uppercase tracking-wide text-n-amber-11">
            {{ $t('CONVERSATION.ARCHIVED_MESSAGE_ALERT.TITLE') }}
          </p>
          <p class="mt-1 text-base font-semibold text-n-slate-12">
            {{
              alert.contact?.name ||
              $t('CONVERSATION.ARCHIVED_MESSAGE_ALERT.CONVERSATION', {
                id: alert.conversation_id,
              })
            }}
          </p>
          <p
            v-if="alert.contact?.phone_number"
            class="mt-1 text-xs text-n-slate-11"
          >
            {{ alert.contact.phone_number }}
          </p>
          <p
            v-if="alert.message"
            class="mt-2 line-clamp-2 text-sm text-n-slate-11"
          >
            {{ alert.message }}
          </p>
        </div>
        <button
          type="button"
          class="shrink-0 rounded-lg px-2 py-1 text-lg text-n-slate-11 hover:bg-n-alpha-2"
          :aria-label="$t('CONVERSATION.ARCHIVED_MESSAGE_ALERT.DISMISS')"
          @click="dismiss(alert.alert_id)"
        >
          <Icon icon="i-lucide-x" class="size-4" />
        </button>
      </div>
      <button
        type="button"
        class="mt-3 w-full rounded-lg bg-n-amber-9 px-3 py-2 text-sm font-semibold text-white hover:bg-n-amber-10"
        @click="openConversation(alert)"
      >
        {{ $t('CONVERSATION.ARCHIVED_MESSAGE_ALERT.OPEN') }}
      </button>
    </article>
  </div>
</template>
