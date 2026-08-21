<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import rottaFollowUpAPI from 'dashboard/api/rottaFollowUp';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';

const TIMEZONE = 'America/Sao_Paulo';

const labelMeta = {
  'primeiro-contato': { title: 'Primeiro contato', color: '#16a34a' },
  'segundo-contato': { title: 'Segundo contato', color: '#f59e0b' },
  'terceiro-contato': { title: 'Terceiro contato', color: '#3b82f6' },
  'ultimo-contato': { title: 'Último contato ❌', color: '#dc2626' },
  'orcamento-feito': { title: 'Orçamento feito ✅', color: '#16a34a' },
  'orcamento-tentativa-2': {
    title: 'Orçamento tentativa 2',
    color: '#f59e0b',
  },
  'orcamento-tentativa-3': {
    title: 'Orçamento tentativa 3',
    color: '#3b82f6',
  },
  'orcamento-tentativa-4': {
    title: 'Orçamento tentativa 4 ❌',
    color: '#dc2626',
  },
  'orcamento-5-dias': { title: 'Orçamento 5 dias', color: '#06b6d4' },
  'orcamento-10-dias': { title: 'Orçamento 10 dias', color: '#4f46e5' },
  'orcamento-15-dias': { title: 'Orçamento 15 dias', color: '#7c3aed' },
  'contato-instantaneo': {
    title: 'Contato instantâneo 🫶',
    color: '#e11d48',
  },
  'orcamento-instantaneo': {
    title: 'Orçamento instantâneo 💰',
    color: '#f97316',
  },
  'clientes-fechados': { title: 'Clientes fechados 🤝', color: '#059669' },
  'kelvin-caio': { title: 'KELVIN / CAIO', color: '#c026d3' },
  arquivado: { title: 'Arquivado', color: '#991b1b' },
};

const jobs = ref([]);
const counts = ref({});
const apiLabels = ref({});
const isLoading = ref(false);
const busyJobId = ref('');
const searchQuery = ref('');
const selectedStage = ref('all');
const timezone = ref(TIMEZONE);
const now = ref(Date.now());
const expandedJobs = ref(new Set());
let refreshTimer;
let clockTimer;

const labelInfo = slug => {
  const fallback = String(slug || 'outros')
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
  return {
    title: apiLabels.value[slug] || labelMeta[slug]?.title || fallback,
    color: labelMeta[slug]?.color || '#64748b',
  };
};

const currentStage = job => job.current_label || job.source_label || '';
const isHistoricalJob = job =>
  job?.status === 'sent_history' || job?.status === 'history_only';

const contactTrail = [
  'contato-instantaneo',
  'primeiro-contato',
  'segundo-contato',
  'terceiro-contato',
  'ultimo-contato',
  'arquivado',
];

const budgetTrail = [
  'orcamento-instantaneo',
  'orcamento-feito',
  'orcamento-tentativa-2',
  'orcamento-tentativa-3',
  'orcamento-tentativa-4',
  'arquivado',
];

const isBudgetStage = stage =>
  String(stage || '').startsWith('orcamento-') || stage === 'clientes-fechados';

const trailFor = job =>
  isBudgetStage(currentStage(job)) || isBudgetStage(job.next_label)
    ? budgetTrail
    : contactTrail;

const nextStageFor = job => {
  const stage = currentStage(job);
  const trail = trailFor(job);
  const index = trail.indexOf(stage);

  if (
    stage === 'orcamento-5-dias' ||
    stage === 'orcamento-10-dias' ||
    stage === 'orcamento-15-dias'
  ) {
    return 'orcamento-feito';
  }

  if (index >= 0 && index < trail.length - 1) return trail[index + 1];
  return job.next_label || '';
};

const deliveryEvidence = job => job?.delivery_evidence;

const historyEntries = job => {
  const rawHistory =
    job.history ||
    job.sent_history ||
    job.dispatched_labels ||
    job.follow_up_history ||
    [];

  const entries = Array.isArray(rawHistory)
    ? rawHistory
        .map(item => {
          if (typeof item === 'string') return { label: item };
          return {
            label: item?.label || item?.slug || item?.name,
            at:
              item?.dispatched_at ||
              item?.sent_at ||
              item?.created_at ||
              item?.at,
          };
        })
        .filter(item => item.label)
    : [];

  // The worker history can be delayed or empty even after Chatwoot has
  // created the outgoing message. Keep that local evidence in the same
  // chronological trail, without changing the worker's source of truth.
  if (deliveryEvidence(job)?.message_id && currentStage(job)) {
    entries.push({
      label: currentStage(job),
      at: deliveryEvidence(job).created_at,
      source: 'chatwoot',
    });
  }

  const latestByLabel = new Map();
  entries.forEach(entry => {
    const previous = latestByLabel.get(entry.label);
    if (
      !previous ||
      (entry.at &&
        (!previous.at ||
          new Date(entry.at).getTime() >= new Date(previous.at).getTime()))
    ) {
      latestByLabel.set(entry.label, entry);
    }
  });
  return [...latestByLabel.values()];
};

const normaliseHistory = job => historyEntries(job).map(entry => entry.label);

const dispatchEntryFor = (job, stage) =>
  historyEntries(job).find(entry => entry.label === stage);

const isStageDispatched = (job, stage) => Boolean(dispatchEntryFor(job, stage));

const evidenceStatusText = job => {
  const status = String(deliveryEvidence(job)?.status || '').toLowerCase();
  if (status === 'read') return 'Lido no WhatsApp';
  if (status === 'delivered') return 'Entregue no WhatsApp';
  if (status === 'sent') return 'Enviado no Chatwoot';
  return 'Mensagem criada no Chatwoot';
};

const evidenceConfirmationText = job => {
  const status = String(deliveryEvidence(job)?.status || '').toLowerCase();
  if (status === 'read') return 'Confirmação de leitura recebida';
  if (status === 'delivered') return 'Confirmação de entrega recebida';
  if (status === 'sent') return 'Aguardando confirmação da Uazapi';
  return 'Evento de envio registrado';
};

const toggleJobHistory = job => {
  const next = new Set(expandedJobs.value);
  if (next.has(job.job_id)) next.delete(job.job_id);
  else next.add(job.job_id);
  expandedJobs.value = next;
};

const isHistoryExpanded = job => expandedJobs.value.has(job.job_id);

const timezoneTitle = computed(() =>
  timezone.value === TIMEZONE ? 'Horário de Brasília' : timezone.value
);

const stageOptions = computed(() => {
  const values = new Set(jobs.value.map(currentStage).filter(Boolean));
  return [...values].sort((a, b) =>
    labelInfo(a).title.localeCompare(labelInfo(b).title, 'pt-BR')
  );
});

const activeJobs = computed(() =>
  jobs.value.filter(job => !isHistoricalJob(job))
);

const filteredJobs = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return jobs.value.filter(job => {
    const matchesStage =
      selectedStage.value === 'all' ||
      currentStage(job) === selectedStage.value;
    const content = [
      job.customer_name,
      job.phone,
      currentStage(job),
      nextStageFor(job),
      labelInfo(currentStage(job)).title,
      labelInfo(nextStageFor(job)).title,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    return matchesStage && (!query || content.includes(query));
  });
});

const dueCount = computed(
  () =>
    activeJobs.value.filter(job => {
      const timestamp = new Date(job.scheduled_at).getTime();
      return Number.isFinite(timestamp) && timestamp <= now.value;
    }).length
);

const formatDate = value => {
  if (!value) return 'Sem data';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Data inválida';
  return new Intl.DateTimeFormat('pt-BR', {
    timeZone: timezone.value || TIMEZONE,
    dateStyle: 'short',
    timeStyle: 'short',
    hour12: false,
  }).format(date);
};

const stageTrailText = (job, stage) => {
  const entry = dispatchEntryFor(job, stage);
  if (entry?.at) return `disparada em ${formatDate(entry.at)}`;
  if (entry) return 'disparada';
  if (currentStage(job) === stage) return 'atual';
  if (nextStageFor(job) === stage) return 'próxima';
  return '';
};

const isDue = value => {
  const date = new Date(value);
  return Number.isFinite(date.getTime()) && date.getTime() <= now.value;
};

const countdownText = value => {
  const target = new Date(value).getTime();
  if (!Number.isFinite(target)) return 'Sem horário definido';

  const difference = target - now.value;
  if (difference <= 0) return 'Pronto para disparar';

  const totalMinutes = Math.ceil(difference / 60000);
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;
  const parts = [];
  if (days) parts.push(`${days} ${days === 1 ? 'dia' : 'dias'}`);
  if (hours) parts.push(`${hours} ${hours === 1 ? 'hora' : 'horas'}`);
  if (!days && minutes) {
    parts.push(`${minutes} ${minutes === 1 ? 'minuto' : 'minutos'}`);
  }
  return `Faltam ${parts.join(' e ')}`;
};

const statusText = (status, job = null) => {
  if (deliveryEvidence(job)?.message_id) return evidenceStatusText(job);
  const values = {
    pending: 'Na fila',
    processing: 'Processando',
    failed_send: 'Falha no envio',
    failed_labels: 'Falha nas etiquetas',
    sent_history: 'Histórico',
    history_only: 'Histórico',
  };
  return values[status] || status || 'Desconhecido';
};

const statusClass = (status, job = null) => {
  if (deliveryEvidence(job)?.message_id) {
    const evidenceStatus = String(
      deliveryEvidence(job).status || ''
    ).toLowerCase();
    if (evidenceStatus === 'read' || evidenceStatus === 'delivered') {
      return 'rotta-status--history';
    }
    return 'rotta-status--processing';
  }
  if (status === 'processing') return 'rotta-status--processing';
  if (status?.startsWith('failed')) return 'rotta-status--error';
  if (status === 'sent_history' || status === 'history_only') {
    return 'rotta-status--history';
  }
  return 'rotta-status--pending';
};

const request = async payload => {
  const response = await rottaFollowUpAPI.create(payload);
  const body = response.data || {};
  if (body.ok === false) {
    throw new Error(body.error || 'Falha no painel de follow-up.');
  }
  return body;
};

const loadQueue = async () => {
  if (isLoading.value) return;
  isLoading.value = true;
  try {
    const body = await request({ action: 'list' });
    jobs.value = Array.isArray(body.jobs) ? body.jobs : [];
    const availableJobIds = new Set(jobs.value.map(job => job.job_id));
    expandedJobs.value = new Set(
      [...expandedJobs.value].filter(jobId => availableJobIds.has(jobId))
    );
    counts.value = body.counts || {};
    apiLabels.value = body.labels || {};
    timezone.value = body.timezone || TIMEZONE;
  } catch (error) {
    useAlert(error.message || 'Não foi possível carregar a fila de follow-up.');
  } finally {
    isLoading.value = false;
  }
};

const runAction = async (job, action, hours = undefined) => {
  if (isHistoricalJob(job)) return;
  busyJobId.value = job.job_id;
  try {
    const payload = { action, job_id: job.job_id };
    if (hours !== undefined) payload.hours = hours;
    await request(payload);
    await loadQueue();
  } catch (error) {
    useAlert(error.message || 'Não foi possível atualizar este follow-up.');
  } finally {
    busyJobId.value = '';
  }
};

const runWithHours = (job, action) => {
  const label = action === 'advance' ? 'adiantar' : 'atrasar';
  // eslint-disable-next-line no-alert
  const value = window.prompt(`Quantas horas deseja ${label}?`, '1');
  if (value === null) return;
  const hours = Number(value);
  if (!Number.isFinite(hours) || hours <= 0) {
    useAlert('Informe uma quantidade de horas maior que zero.');
    return;
  }
  runAction(job, action, Math.min(hours, 720));
};

const openConversation = job => {
  const accountId = job.account_id;
  const conversationId = job.conversation_id;
  if (!accountId || !conversationId) return;
  window.location.href = `/app/accounts/${accountId}/conversations/${conversationId}`;
};

onMounted(async () => {
  await loadQueue();
  clockTimer = window.setInterval(() => {
    now.value = Date.now();
  }, 1000);
  refreshTimer = window.setInterval(loadQueue, 30000);
});

onUnmounted(() => {
  window.clearInterval(clockTimer);
  window.clearInterval(refreshTimer);
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        title="Follow-up da Rotta"
        description="Fila de disparos contextualizados por etiqueta. O n8n mantém a lógica e esta tela apenas acompanha e ajusta os horários."
        search-placeholder="Buscar cliente, telefone ou etiqueta"
      >
        <template #actions>
          <Button
            label="Atualizar"
            icon="i-lucide-refresh-cw"
            size="sm"
            :is-loading="isLoading"
            @click="loadQueue"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <section class="rotta-follow-up" aria-label="Fila de follow-up">
        <div class="rotta-summary-grid">
          <article class="rotta-summary-card">
            <span>Na fila</span>
            <strong>{{ activeJobs.length }}</strong>
            <small
              >{{ jobs.length - activeJobs.length }} histórico(s) no
              painel</small
            >
          </article>
          <article class="rotta-summary-card rotta-summary-card--due">
            <span>Prontos agora</span>
            <strong>{{ dueCount }}</strong>
            <small>aguardando o worker</small>
          </article>
          <article class="rotta-summary-card">
            <span>Etapas ativas</span>
            <strong>{{ stageOptions.length }}</strong>
            <small>trilhas com clientes</small>
          </article>
        </div>

        <div class="rotta-toolbar">
          <div class="rotta-toolbar__title">
            <div class="flex items-center gap-2">
              <Icon icon="i-lucide-clock-3" class="size-5 text-n-brand" />
              <h2>Próximos disparos</h2>
            </div>
            <p>
              {{ timezoneTitle }} · atualização automática a cada 30 segundos
            </p>
          </div>
          <label class="rotta-select-wrap">
            <span>Filtrar etapa</span>
            <select v-model="selectedStage" class="rotta-select">
              <option value="all">Todas as etapas</option>
              <option v-for="stage in stageOptions" :key="stage" :value="stage">
                {{ labelInfo(stage).title }}
              </option>
            </select>
          </label>
        </div>

        <div v-if="isLoading && !jobs.length" class="rotta-empty-state">
          <Icon icon="i-lucide-loader-circle" class="size-5 animate-spin" />
          <span>Carregando a fila…</span>
        </div>

        <div v-else-if="!filteredJobs.length" class="rotta-empty-state">
          <Icon icon="i-lucide-inbox" class="size-6" />
          <div>
            <strong>Nenhum follow-up nesta visão</strong>
            <p>
              Quando uma etiqueta de trilha for aplicada, o job aparecerá aqui.
            </p>
          </div>
        </div>

        <div v-else class="rotta-queue">
          <div class="rotta-queue__desktop">
            <div class="rotta-table-wrap">
              <table class="rotta-table">
                <thead>
                  <tr>
                    <th>Cliente</th>
                    <th>Etiqueta atual</th>
                    <th>Próxima etiqueta</th>
                    <th>Disparo</th>
                    <th>Status</th>
                    <th class="text-right">Ações</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="job in filteredJobs" :key="job.job_id">
                    <td>
                      <button
                        class="rotta-client"
                        type="button"
                        @click="openConversation(job)"
                      >
                        <strong>{{
                          job.customer_name || 'Cliente sem nome'
                        }}</strong>
                        <span>{{ job.phone || 'Telefone não informado' }}</span>
                      </button>
                      <button
                        type="button"
                        class="rotta-history-toggle"
                        :aria-expanded="isHistoryExpanded(job)"
                        @click.stop="toggleJobHistory(job)"
                      >
                        <Icon
                          :icon="
                            isHistoryExpanded(job)
                              ? 'i-lucide-chevron-up'
                              : 'i-lucide-route'
                          "
                          class="size-3.5"
                        />
                        {{
                          isHistoryExpanded(job)
                            ? 'Ocultar trilha'
                            : 'Ver trilha completa'
                        }}
                      </button>
                    </td>
                    <td>
                      <span
                        class="rotta-label-pill"
                        :style="{
                          '--label-color': labelInfo(currentStage(job)).color,
                        }"
                      >
                        {{ labelInfo(currentStage(job)).title }}
                      </span>
                    </td>
                    <td class="text-n-slate-11">
                      <span v-if="nextStageFor(job)">
                        {{ labelInfo(nextStageFor(job)).title }}
                      </span>
                      <span v-else>Ciclo registrado</span>
                    </td>
                    <td>
                      <div
                        v-if="deliveryEvidence(job)?.message_id"
                        class="rotta-schedule rotta-schedule--completed"
                      >
                        <strong>Disparo concluído</strong>
                        <small
                          >Etiqueta:
                          {{ labelInfo(currentStage(job)).title }}</small
                        >
                      </div>
                      <div v-else class="rotta-schedule">
                        <span
                          :class="{
                            'rotta-due':
                              isDue(job.scheduled_at) && !isHistoricalJob(job),
                          }"
                        >
                          {{ formatDate(job.scheduled_at) }}
                        </span>
                        <small
                          :class="{
                            'rotta-due':
                              isDue(job.scheduled_at) && !isHistoricalJob(job),
                          }"
                        >
                          {{
                            isHistoricalJob(job)
                              ? 'Último disparo registrado'
                              : countdownText(job.scheduled_at)
                          }}
                        </small>
                      </div>
                    </td>
                    <td>
                      <span
                        class="rotta-status"
                        :class="statusClass(job.status, job)"
                      >
                        {{ statusText(job.status, job) }}
                      </span>
                      <small
                        v-if="deliveryEvidence(job)?.message_id"
                        class="rotta-delivery-evidence"
                      >
                        {{ labelInfo(currentStage(job)).title }} ·
                        {{ evidenceConfirmationText(job) }}
                      </small>
                    </td>
                    <td>
                      <div v-if="!isHistoricalJob(job)" class="rotta-actions">
                        <Button
                          label="Agora"
                          size="sm"
                          teal
                          :is-loading="busyJobId === job.job_id"
                          @click="runAction(job, 'dispatch_now')"
                        />
                        <Button
                          v-tooltip.top="'Adiantar em horas'"
                          icon="i-lucide-chevrons-up"
                          size="sm"
                          slate
                          ghost
                          :disabled="busyJobId === job.job_id"
                          @click="runWithHours(job, 'advance')"
                        />
                        <Button
                          v-tooltip.top="'Atrasar em horas'"
                          icon="i-lucide-chevrons-down"
                          size="sm"
                          slate
                          ghost
                          :disabled="busyJobId === job.job_id"
                          @click="runWithHours(job, 'delay')"
                        />
                        <Button
                          v-tooltip.top="'Cancelar follow-up'"
                          icon="i-lucide-x"
                          size="sm"
                          ruby
                          ghost
                          :disabled="busyJobId === job.job_id"
                          @click="runAction(job, 'cancel')"
                        />
                      </div>
                      <span v-else class="text-n-slate-11">—</span>
                    </td>
                  </tr>
                  <tr
                    v-for="job in filteredJobs"
                    v-show="isHistoryExpanded(job)"
                    :key="`${job.job_id}-history`"
                    class="rotta-history-row"
                  >
                    <td colspan="6">
                      <div class="rotta-history">
                        <div class="rotta-history__heading">
                          <strong
                            >Trilha de
                            {{ job.customer_name || 'cliente' }}</strong
                          >
                          <span>
                            {{
                              deliveryEvidence(job)?.message_id
                                ? `${labelInfo(currentStage(job)).title} · ${evidenceStatusText(job)} em ${formatDate(deliveryEvidence(job).created_at)} — ${evidenceConfirmationText(job)}`
                                : normaliseHistory(job).length
                                  ? 'Etapas disparadas registradas pelo worker'
                                  : 'Aguardando o histórico de disparos do worker'
                            }}
                          </span>
                        </div>
                        <ol class="rotta-stage-track">
                          <li
                            v-for="stage in trailFor(job)"
                            :key="`${job.job_id}-${stage}`"
                            :class="{
                              'rotta-stage--current':
                                currentStage(job) === stage,
                              'rotta-stage--next': nextStageFor(job) === stage,
                              'rotta-stage--sent': isStageDispatched(
                                job,
                                stage
                              ),
                            }"
                          >
                            <span class="rotta-stage-dot" />
                            <span>{{ labelInfo(stage).title }}</span>
                            <small v-if="stageTrailText(job, stage)">
                              {{ stageTrailText(job, stage) }}
                            </small>
                          </li>
                        </ol>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div class="rotta-queue__mobile">
            <article
              v-for="job in filteredJobs"
              :key="job.job_id"
              class="rotta-job-card"
            >
              <div class="flex items-start justify-between gap-3">
                <button
                  class="rotta-client text-left"
                  type="button"
                  @click="openConversation(job)"
                >
                  <strong>{{ job.customer_name || 'Cliente sem nome' }}</strong>
                  <span>{{ job.phone || 'Telefone não informado' }}</span>
                </button>
                <span
                  class="rotta-status"
                  :class="statusClass(job.status, job)"
                >
                  {{ statusText(job.status, job) }}
                </span>
                <small
                  v-if="deliveryEvidence(job)?.message_id"
                  class="rotta-delivery-evidence"
                >
                  {{ labelInfo(currentStage(job)).title }} ·
                  {{ evidenceConfirmationText(job) }}
                </small>
              </div>
              <button
                type="button"
                class="rotta-history-toggle rotta-history-toggle--mobile"
                :aria-expanded="isHistoryExpanded(job)"
                @click.stop="toggleJobHistory(job)"
              >
                <Icon
                  :icon="
                    isHistoryExpanded(job)
                      ? 'i-lucide-chevron-up'
                      : 'i-lucide-route'
                  "
                  class="size-3.5"
                />
                {{
                  isHistoryExpanded(job)
                    ? 'Ocultar trilha'
                    : 'Ver trilha completa'
                }}
              </button>
              <div v-if="isHistoryExpanded(job)" class="rotta-history">
                <div class="rotta-history__heading">
                  <strong>Trilha do cliente</strong>
                  <span>
                    {{
                      deliveryEvidence(job)?.message_id
                        ? `${labelInfo(currentStage(job)).title} · ${evidenceStatusText(job)} em ${formatDate(deliveryEvidence(job).created_at)} — ${evidenceConfirmationText(job)}`
                        : normaliseHistory(job).length
                          ? 'Etapas disparadas registradas pelo worker'
                          : 'Aguardando o histórico de disparos do worker'
                    }}
                  </span>
                </div>
                <ol class="rotta-stage-track">
                  <li
                    v-for="stage in trailFor(job)"
                    :key="`${job.job_id}-mobile-${stage}`"
                    :class="{
                      'rotta-stage--current': currentStage(job) === stage,
                      'rotta-stage--next': nextStageFor(job) === stage,
                      'rotta-stage--sent': isStageDispatched(job, stage),
                    }"
                  >
                    <span class="rotta-stage-dot" />
                    <span>{{ labelInfo(stage).title }}</span>
                    <small v-if="stageTrailText(job, stage)">
                      {{ stageTrailText(job, stage) }}
                    </small>
                  </li>
                </ol>
              </div>
              <div class="rotta-job-card__details">
                <span
                  class="rotta-label-pill"
                  :style="{
                    '--label-color': labelInfo(currentStage(job)).color,
                  }"
                >
                  {{ labelInfo(currentStage(job)).title }}
                </span>
                <span class="text-n-slate-11">
                  →
                  {{
                    nextStageFor(job)
                      ? labelInfo(nextStageFor(job)).title
                      : 'Ciclo registrado'
                  }}
                </span>
                <span
                  v-if="deliveryEvidence(job)?.message_id"
                  class="rotta-schedule rotta-schedule--completed"
                >
                  <strong>Disparo concluído</strong>
                  <small
                    >Etiqueta: {{ labelInfo(currentStage(job)).title }}</small
                  >
                </span>
                <span v-else class="rotta-schedule">
                  <span
                    :class="{
                      'rotta-due':
                        isDue(job.scheduled_at) && !isHistoricalJob(job),
                    }"
                  >
                    {{ formatDate(job.scheduled_at) }}
                  </span>
                  <small
                    :class="{
                      'rotta-due':
                        isDue(job.scheduled_at) && !isHistoricalJob(job),
                    }"
                  >
                    {{
                      isHistoricalJob(job)
                        ? 'Último disparo registrado'
                        : countdownText(job.scheduled_at)
                    }}
                  </small>
                </span>
              </div>
              <div
                v-if="!isHistoricalJob(job)"
                class="rotta-actions rotta-actions--mobile"
              >
                <Button
                  label="Disparar agora"
                  size="sm"
                  teal
                  :is-loading="busyJobId === job.job_id"
                  @click="runAction(job, 'dispatch_now')"
                />
                <Button
                  label="Adiantar"
                  size="sm"
                  slate
                  ghost
                  :disabled="busyJobId === job.job_id"
                  @click="runWithHours(job, 'advance')"
                />
                <Button
                  label="Atrasar"
                  size="sm"
                  slate
                  ghost
                  :disabled="busyJobId === job.job_id"
                  @click="runWithHours(job, 'delay')"
                />
                <Button
                  label="Cancelar"
                  size="sm"
                  ruby
                  ghost
                  :disabled="busyJobId === job.job_id"
                  @click="runAction(job, 'cancel')"
                />
              </div>
            </article>
          </div>
        </div>

        <div v-if="Object.keys(counts).length" class="rotta-counts">
          <span class="rotta-counts__title">Distribuição da fila</span>
          <span
            v-for="(count, label) in counts"
            :key="label"
            class="rotta-count-chip"
          >
            <i :style="{ backgroundColor: labelInfo(label).color }" />
            {{ labelInfo(label).title }}: <strong>{{ count }}</strong>
          </span>
        </div>
      </section>
    </template>
  </SettingsLayout>
</template>

<style scoped>
.rotta-follow-up {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  width: 100%;
}

.rotta-summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}

.rotta-summary-card,
.rotta-toolbar,
.rotta-table-wrap,
.rotta-job-card,
.rotta-counts {
  @apply bg-n-solid-2 border border-n-weak rounded-2xl;
}

.rotta-summary-card {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  padding: 1rem;
}

.rotta-summary-card span,
.rotta-summary-card small,
.rotta-toolbar p,
.rotta-select-wrap span,
.rotta-counts__title {
  @apply text-n-slate-11;
  font-size: 0.75rem;
}

.rotta-summary-card strong {
  @apply text-n-slate-12;
  font-size: 1.75rem;
  line-height: 1.15;
}

.rotta-summary-card--due strong,
.rotta-due {
  @apply text-n-teal-11;
}

.rotta-toolbar {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem;
}

.rotta-toolbar__title h2 {
  margin: 0;
  @apply text-n-slate-12;
  font-size: 1rem;
  font-weight: 600;
}

.rotta-toolbar__title p {
  margin: 0.35rem 0 0;
}

.rotta-select-wrap {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  min-width: 13rem;
}

.rotta-select {
  height: 2.25rem;
  padding: 0 0.75rem;
  @apply text-n-slate-12 bg-n-solid-1 border border-n-strong rounded-lg;
}

.rotta-empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  min-height: 12rem;
  padding: 2rem;
  @apply text-n-slate-11 bg-n-solid-2 border-n-strong;
  text-align: center;
  border-style: dashed;
  border-radius: 1rem;
}

.rotta-empty-state strong {
  display: block;
  @apply text-n-slate-12;
}

.rotta-empty-state p {
  margin: 0.25rem 0 0;
  font-size: 0.8rem;
}

.rotta-table-wrap {
  overflow-x: auto;
}

.rotta-table {
  width: 100%;
  min-width: 58rem;
  border-collapse: collapse;
}

.rotta-table th,
.rotta-table td {
  padding: 0.85rem 0.9rem;
  @apply border-b border-n-weak;
  text-align: left;
  vertical-align: middle;
}

.rotta-table th {
  @apply text-n-slate-11;
  font-size: 0.7rem;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  white-space: nowrap;
}

.rotta-table tbody tr:last-child td {
  border-bottom: 0;
}

.rotta-client {
  display: flex;
  flex-direction: column;
  min-width: 9rem;
  gap: 0.2rem;
  padding: 0;
  @apply text-n-slate-12;
  text-align: left;
  background: transparent;
  border: 0;
  cursor: pointer;
}

.rotta-client:hover strong {
  @apply text-n-blue-11;
}

.rotta-history-toggle {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  width: fit-content;
  margin-top: 0.35rem;
  padding: 0;
  @apply text-n-blue-11;
  font-size: 0.7rem;
  background: transparent;
  border: 0;
  cursor: pointer;
}

.rotta-history-toggle:hover {
  @apply text-n-blue-12;
}

.rotta-history-row td {
  padding-top: 0;
  @apply bg-n-alpha-1;
}

.rotta-history {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  padding: 0.85rem 0.9rem 1rem;
}

.rotta-history__heading {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
}

.rotta-history__heading strong {
  @apply text-n-slate-12;
  font-size: 0.8rem;
}

.rotta-history__heading span {
  @apply text-n-slate-11;
  font-size: 0.7rem;
}

.rotta-stage-track {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem 0.75rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.rotta-stage-track li {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  @apply text-n-slate-10;
  font-size: 0.7rem;
}

.rotta-stage-dot {
  width: 0.45rem;
  height: 0.45rem;
  background: currentColor;
  border-radius: 999px;
}

.rotta-stage-track li small {
  padding: 0.1rem 0.3rem;
  font-size: 0.62rem;
  @apply text-n-slate-11 bg-n-solid-3;
  border-radius: 999px;
}

.rotta-stage--current {
  @apply text-n-blue-11;
  font-weight: 600;
}

.rotta-stage--next {
  @apply text-n-amber-11;
}

.rotta-stage--sent {
  @apply text-n-teal-11;
}

.rotta-stage--sent .rotta-stage-dot {
  @apply bg-n-teal-9;
}

.rotta-history-toggle--mobile {
  margin-top: 0;
}

.rotta-client strong {
  overflow: hidden;
  font-size: 0.85rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-client span {
  @apply text-n-slate-11;
  font-size: 0.75rem;
}

.rotta-label-pill {
  display: inline-flex;
  align-items: center;
  width: fit-content;
  max-width: 13rem;
  padding: 0.25rem 0.5rem;
  overflow: hidden;
  @apply text-n-slate-12;
  font-size: 0.75rem;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
  background: color-mix(in srgb, var(--label-color) 12%, transparent);
  border: 1px solid color-mix(in srgb, var(--label-color) 45%, transparent);
  border-radius: 999px;
}

.rotta-schedule {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  white-space: nowrap;
}

.rotta-schedule small {
  @apply text-n-slate-11;
  font-size: 0.7rem;
}

.rotta-schedule--completed strong {
  @apply text-n-teal-11;
  font-size: 0.75rem;
}

.rotta-schedule--completed small {
  max-width: 13rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-status {
  display: inline-flex;
  padding: 0.25rem 0.5rem;
  font-size: 0.7rem;
  font-weight: 600;
  white-space: nowrap;
  border-radius: 999px;
}

.rotta-status--pending {
  @apply text-n-blue-11 bg-n-blue-2;
}

.rotta-status--processing {
  @apply text-n-amber-11 bg-n-amber-2;
}

.rotta-status--error {
  @apply text-n-ruby-11 bg-n-ruby-2;
}

.rotta-status--history {
  @apply text-n-slate-11 bg-n-slate-2;
}

.rotta-delivery-evidence {
  @apply text-n-slate-11;
  display: block;
  margin-top: 0.25rem;
  font-size: 0.7rem;
  line-height: 1.25;
}

.rotta-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.35rem;
  white-space: nowrap;
}

.rotta-queue__mobile {
  display: none;
}

.rotta-job-card {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
  padding: 1rem;
}

.rotta-job-card__details {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
}

.rotta-actions--mobile {
  justify-content: flex-start;
  flex-wrap: wrap;
}

.rotta-counts {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
}

.rotta-counts__title {
  margin-right: 0.25rem;
  font-weight: 600;
}

.rotta-count-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.25rem 0.5rem;
  @apply text-n-slate-11 bg-n-alpha-1;
  font-size: 0.7rem;
  border-radius: 999px;
}

.rotta-count-chip i {
  width: 0.45rem;
  height: 0.45rem;
  border-radius: 999px;
}

@media (max-width: 1023px) {
  .rotta-queue__desktop {
    display: none;
  }

  .rotta-queue__mobile {
    display: grid;
    gap: 0.75rem;
  }
}

@media (max-width: 640px) {
  .rotta-summary-grid {
    grid-template-columns: 1fr;
  }

  .rotta-summary-card {
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: center;
    column-gap: 0.75rem;
  }

  .rotta-summary-card strong {
    grid-row: span 2;
    grid-column: 2;
  }

  .rotta-toolbar {
    align-items: stretch;
    flex-direction: column;
  }

  .rotta-select-wrap {
    min-width: 0;
  }

  .rotta-actions--mobile :deep(button) {
    flex: 1 1 auto;
  }

  .rotta-schedule {
    white-space: normal;
  }
}
</style>
