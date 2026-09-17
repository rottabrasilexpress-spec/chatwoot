<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import rottaFollowUpAPI from 'dashboard/api/rottaFollowUp';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import {
  canonicalFollowUpStage,
  currentStageFor,
  FOLLOW_UP_STAGE_TITLES,
  isArchivedStage,
  isHistoricalJob,
  nextFollowUpStageFor,
} from '../../settings/labels/followUpHelpers';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const jobs = ref([]);
const isLoading = ref(false);
const busyJobId = ref('');
const dispatchDialogRef = ref(null);
const pendingDispatchJob = ref(null);
let refreshTimer;
let requestSequence = 0;

const activeJobs = computed(() =>
  jobs.value.filter(job => {
    const stage = canonicalFollowUpStage(currentStageFor(job));
    return (
      String(job.conversation_id) === String(props.conversationId) &&
      stage &&
      !isArchivedStage(stage) &&
      !isHistoricalJob(job)
    );
  })
);

const stageTitle = stage =>
  FOLLOW_UP_STAGE_TITLES[canonicalFollowUpStage(stage)] ||
  String(stage || 'Etapa não informada').replaceAll('-', ' ');

const formatDate = value => {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) return 'Aguardando horário';
  return new Intl.DateTimeFormat('pt-BR', {
    timeZone: 'America/Sao_Paulo',
    dateStyle: 'short',
    timeStyle: 'short',
    hour12: false,
  }).format(date);
};

const request = async payload => {
  const response = await rottaFollowUpAPI.create(payload);
  if (response.data?.ok === false) throw new Error(response.data.error);
  return response.data || {};
};

const loadJobs = async () => {
  requestSequence += 1;
  const sequence = requestSequence;
  isLoading.value = true;
  try {
    const body = await request({ action: 'list' });
    if (sequence === requestSequence) jobs.value = body.jobs || [];
  } catch (error) {
    if (sequence === requestSequence) {
      useAlert(error.message || 'Não foi possível consultar o follow-up.');
    }
  } finally {
    if (sequence === requestSequence) isLoading.value = false;
  }
};

const runAction = async (job, action, hours) => {
  if (busyJobId.value) return;
  busyJobId.value = job.job_id;
  try {
    await request({
      action,
      job_id: job.job_id,
      conversation_id: job.conversation_id,
      ...(hours ? { hours } : {}),
    });
    await loadJobs();
    let successMessage = 'Disparo solicitado.';
    if (action === 'advance')
      successMessage = 'Follow-up adiantado em 24 horas.';
    if (action === 'delay') successMessage = 'Follow-up atrasado em 24 horas.';
    useAlert(successMessage);
  } catch (error) {
    useAlert(error.message || 'Não foi possível atualizar o follow-up.');
  } finally {
    busyJobId.value = '';
  }
};

const askDispatchNow = job => {
  pendingDispatchJob.value = job;
  dispatchDialogRef.value?.open();
};

const confirmDispatchNow = async () => {
  if (!pendingDispatchJob.value) return;
  await runAction(pendingDispatchJob.value, 'dispatch_now');
  dispatchDialogRef.value?.close();
  pendingDispatchJob.value = null;
};

const scheduleRefresh = () => window.setTimeout(loadJobs, 400);

watch(() => props.conversationId, loadJobs);
onMounted(() => {
  loadJobs();
  emitter.on(BUS_EVENTS.ROTTA_FOLLOW_UP_REFRESH, scheduleRefresh);
  emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT, scheduleRefresh);
  refreshTimer = window.setInterval(loadJobs, 5000);
});
onUnmounted(() => {
  requestSequence += 1;
  emitter.off(BUS_EVENTS.ROTTA_FOLLOW_UP_REFRESH, scheduleRefresh);
  emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT, scheduleRefresh);
  window.clearInterval(refreshTimer);
});
</script>

<template>
  <section
    v-if="isLoading || activeJobs.length"
    class="rotta-profile-follow-up"
  >
    <header>
      <div>
        <span>Follow-up ativo</span>
        <small>Sincronizado com a fila operacional</small>
      </div>
      <Icon
        v-if="isLoading"
        icon="i-lucide-loader-circle"
        class="size-4 animate-spin"
      />
      <Icon v-else icon="i-lucide-route" class="size-4 text-n-brand" />
    </header>

    <article v-for="job in activeJobs" :key="job.job_id">
      <div class="rotta-profile-follow-up__stage">
        <strong>{{ stageTitle(currentStageFor(job)) }}</strong>
        <span v-if="nextFollowUpStageFor(job)"
          >Próxima: {{ stageTitle(nextFollowUpStageFor(job)) }}</span
        >
      </div>
      <div class="rotta-profile-follow-up__schedule">
        <Icon icon="i-lucide-clock-3" class="size-4" />
        <span>{{ formatDate(job.scheduled_at) }}</span>
      </div>
      <div class="rotta-profile-follow-up__actions">
        <Button
          label="−1 dia"
          size="sm"
          slate
          ghost
          :disabled="busyJobId === job.job_id"
          @click="runAction(job, 'advance', 24)"
        />
        <Button
          label="+1 dia"
          size="sm"
          slate
          ghost
          :disabled="busyJobId === job.job_id"
          @click="runAction(job, 'delay', 24)"
        />
        <Button
          label="Disparar agora"
          size="sm"
          teal
          :is-loading="busyJobId === job.job_id"
          @click="askDispatchNow(job)"
        />
      </div>
    </article>

    <Dialog
      ref="dispatchDialogRef"
      type="alert"
      title="Disparar follow-up agora?"
      confirm-button-label="Sim, disparar agora"
      cancel-button-label="Voltar"
      :is-loading="Boolean(busyJobId)"
      @confirm="confirmDispatchNow"
      @close="pendingDispatchJob = null"
    >
      <p v-if="pendingDispatchJob" class="text-sm leading-6 text-n-slate-11">
        A mensagem de
        <strong class="text-n-slate-12">{{
          stageTitle(currentStageFor(pendingDispatchJob))
        }}</strong>
        será disparada imediatamente no WhatsApp. O horário agendado será
        antecipado.
      </p>
    </Dialog>
  </section>
</template>

<style scoped>
.rotta-profile-follow-up {
  display: grid;
  gap: 0.75rem;
  margin: 0.75rem 0.5rem 0;
  border: 1px solid var(--color-n-weak);
  border-radius: 0.75rem;
  padding: 0.875rem;
  background: var(--color-n-alpha-2);
  box-shadow: inset 0 2px 0 var(--color-n-brand);
}

.rotta-profile-follow-up header,
.rotta-profile-follow-up header > div,
.rotta-profile-follow-up article,
.rotta-profile-follow-up__stage {
  display: flex;
}

.rotta-profile-follow-up header {
  align-items: center;
  justify-content: space-between;
}

.rotta-profile-follow-up header > div,
.rotta-profile-follow-up article,
.rotta-profile-follow-up__stage {
  flex-direction: column;
}

.rotta-profile-follow-up header span,
.rotta-profile-follow-up__stage strong {
  color: var(--color-n-slate-12);
  font-size: 0.875rem;
  font-weight: 600;
}

.rotta-profile-follow-up header small,
.rotta-profile-follow-up__stage span {
  color: var(--color-n-slate-10);
  font-size: 0.75rem;
}

.rotta-profile-follow-up article {
  gap: 0.625rem;
  border-top: 1px solid var(--color-n-weak);
  padding-top: 0.75rem;
}

.rotta-profile-follow-up__schedule,
.rotta-profile-follow-up__actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.rotta-profile-follow-up__schedule {
  color: var(--color-n-slate-11);
  font-size: 0.75rem;
}

.rotta-profile-follow-up__actions {
  flex-wrap: wrap;
}

.rotta-profile-follow-up__actions :deep(button) {
  min-height: 2.5rem;
  flex: 1 1 auto;
}
</style>
