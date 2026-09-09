<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useAlert } from 'dashboard/composables';
import rottaFollowUpAPI from 'dashboard/api/rottaFollowUp';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import {
  CONFIGURED_DELAY_HOURS,
  countdownPartsFor,
  currentStageFor,
  delayHoursFor,
  dispatchWindowFor,
  effectiveDispatchAt,
  FOLLOW_UP_STAGE_ORDER,
  isHistoricalJob,
  kanbanBucketFor,
  orderedFollowUpStages,
} from './followUpHelpers';

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
const responseMeta = ref({});
const isLoading = ref(false);
const busyJobId = ref('');
const searchQuery = ref('');
const selectedStage = ref('all');
const timezone = ref(TIMEZONE);
const now = ref(Date.now());
const lastSyncedAt = ref(null);
const expandedJobs = ref(new Set());
const pendingEnrollments = ref([]);
const selectedView = ref('stages');
const customHours = ref({});
let refreshTimer;
let clockTimer;
let realtimeRefreshTimer;
let settleRefreshTimer;
let fastRefreshTimers = [];
let refreshRequested = false;
let isMounted = false;
let loadQueue;

const REALTIME_REFRESH_DEBOUNCE_MS = 400;
const REALTIME_SETTLE_REFRESH_MS = 1200;
const FAST_REFRESH_DELAYS_MS = [300, 1000, 2500, 5000];

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

const slugForLabel = value => {
  const normalized = String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/^\[\d+\]\s*/, '')
    .replace(/[✅❌🫶💰🤝]/gu, '')
    .trim();
  const metadataMatch = Object.entries(labelMeta).find(([, metadata]) => {
    const title = metadata.title
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[✅❌🫶💰🤝]/gu, '')
      .trim()
      .toLowerCase();
    return title === normalized;
  });
  if (metadataMatch) return metadataMatch[0];
  return normalized.replace(/\s+/g, '-');
};

const linkedLabelSlugs = new Set(Object.keys(CONFIGURED_DELAY_HOURS));

const currentStage = currentStageFor;

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

const kanbanColumns = [
  {
    key: 'ready',
    title: 'Prontos agora',
    description: 'Dentro da janela e aguardando o worker',
    icon: 'i-lucide-zap',
  },
  {
    key: 'today',
    title: 'Hoje',
    description: 'Programados para o dia de hoje',
    icon: 'i-lucide-sun',
  },
  {
    key: 'tomorrow',
    title: 'Amanhã',
    description: 'Próxima janela do calendário',
    icon: 'i-lucide-calendar-days',
  },
  {
    key: 'upcoming',
    title: 'Próximos dias',
    description: 'Agendamentos além de amanhã',
    icon: 'i-lucide-calendar-clock',
  },
  {
    key: 'attention',
    title: 'Atenção',
    description: 'Falha, horário ausente ou conciliação pendente',
    icon: 'i-lucide-triangle-alert',
  },
  {
    key: 'history',
    title: 'Histórico',
    description: 'Etapas já registradas',
    icon: 'i-lucide-history',
  },
];

const pendingJobKey = item => `${item.conversation_id}:${item.label}`;

const pendingJobs = computed(() =>
  pendingEnrollments.value.map(item => ({
    job_id: `pending:${pendingJobKey(item)}`,
    conversation_id: item.conversation_id,
    account_id: item.account_id,
    customer_name: item.customer_name,
    phone: item.phone,
    source_label: item.label,
    current_label: item.label,
    next_label: nextStageFor({ source_label: item.label }),
    status: now.value - item.created_at > 15000 ? 'sync_failed' : 'syncing',
    pending_enrollment: true,
    pending_age_ms: now.value - item.created_at,
  }))
);

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

const dispatchWindow = job => dispatchWindowFor(job, responseMeta.value);

const queueJobs = computed(() => {
  const returnedKeys = new Set(
    jobs.value.map(job => `${job.conversation_id}:${currentStage(job)}`)
  );
  const waiting = pendingJobs.value.filter(
    job => !returnedKeys.has(`${job.conversation_id}:${currentStage(job)}`)
  );
  return [...waiting, ...jobs.value];
});

const stageOptions = computed(() => {
  const values = new Set(queueJobs.value.map(currentStage).filter(Boolean));
  return [...values].sort((a, b) =>
    labelInfo(a).title.localeCompare(labelInfo(b).title, 'pt-BR')
  );
});

const trailColumnDefinitions = [
  {
    key: 'instant',
    title: 'Instantâneos',
    description: 'Entradas rápidas para iniciar ou retomar o atendimento.',
    icon: 'i-lucide-zap',
    stages: ['contato-instantaneo', 'orcamento-instantaneo'],
  },
  {
    key: 'contact',
    title: 'Trilha de contato',
    description: 'Cadência de relacionamento antes do orçamento.',
    icon: 'i-lucide-route',
    stages: [
      'primeiro-contato',
      'segundo-contato',
      'terceiro-contato',
      'ultimo-contato',
    ],
  },
  {
    key: 'budget',
    title: 'Trilha de orçamento',
    description: 'Tentativas e lembretes para converter o orçamento.',
    icon: 'i-lucide-badge-dollar-sign',
    stages: [
      'orcamento-feito',
      'orcamento-tentativa-2',
      'orcamento-tentativa-3',
      'orcamento-tentativa-4',
      'orcamento-5-dias',
      'orcamento-10-dias',
      'orcamento-15-dias',
    ],
  },
  {
    key: 'closing',
    title: 'Encerramento',
    description: 'Conversões concluídas e contatos fora da operação ativa.',
    icon: 'i-lucide-handshake',
    stages: ['clientes-fechados', 'arquivado'],
  },
];

const trailColumns = computed(() => {
  const stages = orderedFollowUpStages([
    ...FOLLOW_UP_STAGE_ORDER,
    ...queueJobs.value.map(currentStage),
  ]);
  const groupedStages = new Set(
    trailColumnDefinitions.flatMap(column => column.stages)
  );
  const additionalStages = stages.filter(stage => !groupedStages.has(stage));

  return [
    ...trailColumnDefinitions,
    ...(additionalStages.length
      ? [
          {
            key: 'other',
            title: 'Outras etapas',
            description: 'Etiquetas adicionais mantidas no fluxo.',
            icon: 'i-lucide-tags',
            stages: additionalStages,
          },
        ]
      : []),
  ].map(column => ({
    ...column,
    stageKeys: column.stages,
  }));
});

const activeJobs = computed(() =>
  queueJobs.value.filter(job => !isHistoricalJob(job))
);

const bucketFor = job => kanbanBucketFor(job, now.value, responseMeta.value);

const viewCount = view => {
  if (view === 'stages') return activeJobs.value.length;
  if (view === 'active') return activeJobs.value.length;
  if (view === 'all') return queueJobs.value.length;
  return queueJobs.value.filter(job => bucketFor(job) === view).length;
};

const viewOptions = computed(() => [
  { key: 'stages', title: 'Etapas' },
  { key: 'all', title: 'Todos' },
  { key: 'active', title: 'Ativos' },
  ...kanbanColumns.map(({ key, title }) => ({ key, title })),
]);

const visibleColumns = computed(() =>
  ['stages', 'all'].includes(selectedView.value)
    ? trailColumns.value
    : kanbanColumns.filter(column => {
        if (selectedView.value === 'active') return column.key !== 'history';
        return selectedView.value === column.key;
      })
);

const filteredJobs = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return queueJobs.value.filter(job => {
    const bucket = bucketFor(job);
    const matchesView = ['stages', 'active'].includes(selectedView.value)
      ? !isHistoricalJob(job)
      : selectedView.value === 'all' || bucket === selectedView.value;
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
    return matchesView && matchesStage && (!query || content.includes(query));
  });
});

const jobsForColumn = columnKey => {
  const groupedColumn = trailColumns.value.find(
    column => column.key === columnKey
  );
  const jobsInColumn = filteredJobs.value.filter(job =>
    groupedColumn?.stageKeys
      ? groupedColumn.stageKeys.includes(currentStage(job))
      : bucketFor(job) === columnKey
  );

  if (!groupedColumn) return jobsInColumn;

  const stageOrder = new Map(
    groupedColumn.stageKeys.map((stage, index) => [stage, index])
  );
  return [...jobsInColumn].sort(
    (left, right) =>
      (stageOrder.get(currentStage(left)) ?? Number.MAX_SAFE_INTEGER) -
      (stageOrder.get(currentStage(right)) ?? Number.MAX_SAFE_INTEGER)
  );
};

const dueCount = computed(
  () =>
    activeJobs.value.filter(job => {
      const timestamp = effectiveDispatchAt(
        job.scheduled_at,
        now.value,
        dispatchWindow(job)
      );
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

const isDue = job => {
  const target = effectiveDispatchAt(
    job?.scheduled_at,
    now.value,
    dispatchWindow(job)
  );
  return Number.isFinite(target) && target <= now.value;
};

const countdownText = job => {
  const target = effectiveDispatchAt(
    job?.scheduled_at,
    now.value,
    dispatchWindow(job)
  );
  return countdownPartsFor(target, now.value).text;
};

const delayText = job => {
  const metadata = delayHoursFor(job);
  if (metadata.hours === null) return 'Delay não informado';
  if (metadata.hours === 0) return 'Imediato';
  return `${metadata.hours}h programadas${metadata.source === 'configured' ? ' · configuração Rotta' : ''}`;
};

const windowText = job => {
  const window = dispatchWindow(job);
  const source = window.source === 'api' ? '' : ' · padrão Rotta';
  return `${window.start}–${window.end} BRT${source}`;
};

const scheduleText = job => {
  if (job.pending_enrollment) {
    return job.status === 'sync_failed'
      ? 'Conciliação não confirmada'
      : 'Sincronizando etiqueta…';
  }
  if (!job.scheduled_at) return 'Sem horário definido';
  const target = effectiveDispatchAt(
    job.scheduled_at,
    now.value,
    dispatchWindow(job)
  );
  if (!Number.isFinite(target)) return 'Sem horário definido';
  return formatDate(target);
};

const statusText = (status, job = null) => {
  if (deliveryEvidence(job)?.message_id) return evidenceStatusText(job);
  const values = {
    pending: 'Na fila',
    processing: 'Processando',
    syncing: 'Sincronizando etiqueta',
    sync_failed: 'Conciliação pendente',
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
  if (status === 'syncing') return 'rotta-status--processing';
  if (status === 'sync_failed') return 'rotta-status--error';
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

const registerPendingEnrollment = data => {
  const conversation = data?.conversation || {};
  const conversationId = data?.conversation_id || data?.id || conversation.id;
  if (!conversationId) return;

  const labels = data?.labels || conversation.labels || data?.label_list || [];
  const linkedLabels = Array.isArray(labels)
    ? labels.map(slugForLabel).filter(label => linkedLabelSlugs.has(label))
    : [];
  if (!linkedLabels.length) return;

  const details = {
    conversation_id: conversationId,
    account_id: data?.account_id || conversation.account_id,
    customer_name:
      data?.customer_name ||
      conversation.meta?.sender?.name ||
      conversation.contact?.name,
    phone:
      data?.phone ||
      conversation.meta?.sender?.phone_number ||
      conversation.contact?.phone_number,
    created_at: Date.now(),
  };
  const current = new Map(
    pendingEnrollments.value.map(item => [pendingJobKey(item), item])
  );
  linkedLabels.forEach(label => {
    const item = { ...details, label };
    current.set(pendingJobKey(item), item);
  });
  pendingEnrollments.value = [...current.values()];
};

const scheduleFastRefresh = () => {
  fastRefreshTimers.forEach(timer => window.clearTimeout(timer));
  fastRefreshTimers = FAST_REFRESH_DELAYS_MS.map(delay =>
    window.setTimeout(loadQueue, delay)
  );
};

function scheduleRealtimeRefresh(data) {
  if (!isMounted) return;
  registerPendingEnrollment(data);
  window.clearTimeout(realtimeRefreshTimer);
  window.clearTimeout(settleRefreshTimer);
  scheduleFastRefresh();
  realtimeRefreshTimer = window.setTimeout(() => {
    realtimeRefreshTimer = undefined;
    loadQueue();
    settleRefreshTimer = window.setTimeout(() => {
      settleRefreshTimer = undefined;
      loadQueue();
    }, REALTIME_SETTLE_REFRESH_MS);
  }, REALTIME_REFRESH_DEBOUNCE_MS);
}

loadQueue = async () => {
  if (isLoading.value) {
    refreshRequested = true;
    return;
  }
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
    responseMeta.value = {
      ...(body.meta || {}),
      ...(body.config || {}),
      timezone: body.timezone || body.meta?.timezone || TIMEZONE,
    };
    const returnedKeys = new Set(
      jobs.value.map(job => `${job.conversation_id}:${currentStage(job)}`)
    );
    pendingEnrollments.value = pendingEnrollments.value.filter(
      item =>
        !returnedKeys.has(pendingJobKey(item)) &&
        now.value - item.created_at < 60000
    );
    lastSyncedAt.value = Date.now();
  } catch (error) {
    useAlert(error.message || 'Não foi possível carregar a fila de follow-up.');
  } finally {
    isLoading.value = false;
    if (refreshRequested && isMounted) {
      refreshRequested = false;
      window.setTimeout(loadQueue, REALTIME_REFRESH_DEBOUNCE_MS);
    }
  }
};

const runAction = async (job, action, hours = undefined) => {
  if (isHistoricalJob(job)) return;
  if (job.pending_enrollment && action !== 'remove_label') return;
  busyJobId.value = job.job_id;
  try {
    const payload = { action, job_id: job.job_id };
    if (hours !== undefined) payload.hours = hours;
    if (action === 'remove_label') {
      payload.conversation_id = job.conversation_id;
      payload.label = currentStage(job);
    }
    await request(payload);
    pendingEnrollments.value = pendingEnrollments.value.filter(
      item =>
        pendingJobKey(item) !== `${job.conversation_id}:${currentStage(job)}`
    );
    await loadQueue();
  } catch (error) {
    useAlert(error.message || 'Não foi possível atualizar este follow-up.');
  } finally {
    busyJobId.value = '';
  }
};

const runWithHours = (job, action) => {
  const hours = Number(customHours.value[job.job_id]);
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
  isMounted = true;
  emitter.on(BUS_EVENTS.ROTTA_FOLLOW_UP_REFRESH, scheduleRealtimeRefresh);
  emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT, scheduleRealtimeRefresh);
  await loadQueue();
  clockTimer = window.setInterval(() => {
    now.value = Date.now();
  }, 1000);
  refreshTimer = window.setInterval(loadQueue, 30000);
});

onUnmounted(() => {
  isMounted = false;
  emitter.off(BUS_EVENTS.ROTTA_FOLLOW_UP_REFRESH, scheduleRealtimeRefresh);
  emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT, scheduleRealtimeRefresh);
  window.clearInterval(clockTimer);
  window.clearInterval(refreshTimer);
  window.clearTimeout(realtimeRefreshTimer);
  window.clearTimeout(settleRefreshTimer);
  fastRefreshTimers.forEach(timer => window.clearTimeout(timer));
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        title="Follow-up da Rotta"
        description="Kanban operacional por etiqueta, janela de envio e trilha do cliente. O n8n continua como executor do WhatsApp."
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
              >{{ queueJobs.length - activeJobs.length }} histórico(s) no
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
              <h2>Quadro de follow-ups</h2>
            </div>
            <p>
              {{ timezoneTitle }} ·
              {{
                lastSyncedAt
                  ? `ao vivo · sincronizado em ${formatDate(lastSyncedAt)}`
                  : 'sincronizando…'
              }}
              · janela {{ dispatchWindow({}).start }}–{{
                dispatchWindow({}).end
              }}
            </p>
          </div>
          <div
            class="rotta-view-tabs"
            role="tablist"
            aria-label="Visão do quadro"
          >
            <button
              v-for="view in viewOptions"
              :key="view.key"
              type="button"
              role="tab"
              :aria-selected="selectedView === view.key"
              :class="{ 'rotta-view-tab--active': selectedView === view.key }"
              @click="selectedView = view.key"
            >
              {{ view.title }}
              <span>{{ viewCount(view.key) }}</span>
            </button>
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

        <div v-if="isLoading && !queueJobs.length" class="rotta-empty-state">
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
          <div
            class="rotta-board"
            :class="{
              'rotta-board--trails': ['stages', 'all'].includes(selectedView),
            }"
            aria-label="Quadro de follow-ups"
          >
            <article
              v-for="column in visibleColumns"
              :key="column.key"
              class="rotta-board-column"
              :class="`rotta-board-column--${column.key}`"
            >
              <header class="rotta-board-column__header">
                <div class="rotta-board-column__title">
                  <Icon :icon="column.icon" class="size-4" />
                  <h3>{{ column.title }}</h3>
                  <span>{{ jobsForColumn(column.key).length }}</span>
                </div>
                <p>{{ column.description }}</p>
                <div
                  v-if="column.stageKeys"
                  class="rotta-board-column__stages"
                  :aria-label="`Etapas de ${column.title}`"
                >
                  <span
                    v-for="stage in column.stageKeys"
                    :key="stage"
                    class="rotta-stage-chip"
                    :style="{
                      '--stage-color': labelInfo(stage).color,
                    }"
                  >
                    {{ labelInfo(stage).title }}
                  </span>
                </div>
              </header>

              <div
                v-if="jobsForColumn(column.key).length"
                class="rotta-board-column__body"
              >
                <article
                  v-for="job in jobsForColumn(column.key)"
                  :key="job.job_id"
                  class="rotta-board-card"
                  :class="{
                    'rotta-board-card--expanded': isHistoryExpanded(job),
                  }"
                  tabindex="0"
                  role="button"
                  :aria-expanded="isHistoryExpanded(job)"
                  :aria-label="`Mostrar detalhes de ${job.customer_name || 'cliente'}. Duplo clique para abrir a conversa.`"
                  @click="toggleJobHistory(job)"
                  @dblclick.stop="openConversation(job)"
                  @keydown.enter="toggleJobHistory(job)"
                  @keydown.space.prevent="toggleJobHistory(job)"
                >
                  <div class="rotta-board-card__topline">
                    <button
                      class="rotta-client rotta-client--board"
                      type="button"
                      @click.stop="toggleJobHistory(job)"
                      @dblclick.stop="openConversation(job)"
                    >
                      <strong>{{
                        job.customer_name || 'Cliente sem nome'
                      }}</strong>
                      <span>{{ job.phone || 'Telefone não informado' }}</span>
                    </button>
                    <span
                      class="rotta-status"
                      :class="statusClass(job.status, job)"
                    >
                      {{ statusText(job.status, job) }}
                    </span>
                  </div>

                  <div class="rotta-board-card__labels">
                    <span
                      class="rotta-label-pill"
                      :style="{
                        '--label-color': labelInfo(currentStage(job)).color,
                      }"
                    >
                      {{ labelInfo(currentStage(job)).title }}
                    </span>
                    <span
                      v-if="nextStageFor(job)"
                      class="rotta-board-card__next"
                    >
                      <Icon icon="i-lucide-arrow-right" class="size-3.5" />
                      {{ labelInfo(nextStageFor(job)).title }}
                    </span>
                  </div>

                  <div
                    v-if="isHistoryExpanded(job)"
                    class="rotta-board-card__schedule"
                  >
                    <div class="rotta-board-card__schedule-main">
                      <Icon
                        icon="i-lucide-clock-3"
                        class="size-4 text-n-brand"
                      />
                      <div>
                        <strong>{{ scheduleText(job) }}</strong>
                        <small
                          v-if="
                            !job.pending_enrollment && !isHistoricalJob(job)
                          "
                        >
                          {{
                            isDue(job)
                              ? 'Pronto para disparar'
                              : countdownText(job)
                          }}
                        </small>
                        <small v-else-if="isHistoricalJob(job)"
                          >Último disparo registrado</small
                        >
                        <small v-else
                          >O job será substituído aqui assim que o n8n
                          confirmar</small
                        >
                      </div>
                    </div>
                    <div class="rotta-board-card__schedule-meta">
                      <span>{{ delayText(job) }}</span>
                      <span>{{ windowText(job) }}</span>
                    </div>
                  </div>

                  <div v-else class="rotta-board-card__compact-meta">
                    <span>{{ scheduleText(job) }}</span>
                    <span>{{ statusText(job.status, job) }}</span>
                  </div>

                  <div
                    v-if="isHistoryExpanded(job)"
                    class="rotta-board-card__footer"
                  >
                    <button
                      type="button"
                      class="rotta-history-toggle rotta-history-toggle--icon"
                      :aria-expanded="isHistoryExpanded(job)"
                      :aria-label="
                        isHistoryExpanded(job)
                          ? 'Ocultar trilha'
                          : 'Mostrar trilha'
                      "
                      :title="
                        isHistoryExpanded(job)
                          ? 'Ocultar trilha'
                          : 'Mostrar trilha'
                      "
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
                    </button>
                    <span
                      v-if="deliveryEvidence(job)?.message_id"
                      class="rotta-delivery-evidence"
                    >
                      {{ evidenceConfirmationText(job) }}
                    </span>
                  </div>

                  <div
                    v-if="isHistoryExpanded(job) && !isHistoricalJob(job)"
                    class="rotta-board-card__actions"
                    @click.stop
                  >
                    <template v-if="job.pending_enrollment">
                      <span class="rotta-board-card__hint">
                        <Icon icon="i-lucide-radio-tower" class="size-3.5" />
                        {{
                          job.status === 'sync_failed'
                            ? 'Confira o webhook do n8n'
                            : 'Atualização em tempo real'
                        }}
                      </span>
                    </template>
                    <template v-else>
                      <Button
                        label="Disparar agora"
                        size="sm"
                        teal
                        :is-loading="busyJobId === job.job_id"
                        @click="runAction(job, 'dispatch_now')"
                      />
                      <label class="rotta-hours-input">
                        <span>Horas</span>
                        <input
                          v-model.number="customHours[job.job_id]"
                          type="number"
                          min="0.25"
                          max="720"
                          step="0.25"
                          inputmode="decimal"
                          aria-label="Quantidade de horas"
                        />
                      </label>
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
                    </template>
                    <Button
                      label="Remover etiqueta"
                      size="sm"
                      ruby
                      ghost
                      :disabled="busyJobId === job.job_id"
                      @click="runAction(job, 'remove_label')"
                    />
                  </div>

                  <div
                    v-if="isHistoryExpanded(job)"
                    class="rotta-history rotta-history--board"
                  >
                    <div class="rotta-history__heading">
                      <strong
                        >Trilha de {{ job.customer_name || 'cliente' }}</strong
                      >
                      <span>
                        {{
                          deliveryEvidence(job)?.message_id
                            ? `${labelInfo(currentStage(job)).title} · ${evidenceStatusText(job)} em ${formatDate(deliveryEvidence(job).created_at)} — ${evidenceConfirmationText(job)}`
                            : normaliseHistory(job).length
                              ? 'Etapas disparadas registradas pelo worker'
                              : job.pending_enrollment
                                ? 'Etiqueta recebida; aguardando o job correspondente do n8n'
                                : 'Aguardando o histórico de disparos do worker'
                        }}
                      </span>
                    </div>
                    <ol class="rotta-stage-track">
                      <li
                        v-for="stage in trailFor(job)"
                        :key="`${job.job_id}-board-${stage}`"
                        :class="{
                          'rotta-stage--current': currentStage(job) === stage,
                          'rotta-stage--next': nextStageFor(job) === stage,
                          'rotta-stage--sent': isStageDispatched(job, stage),
                        }"
                      >
                        <span class="rotta-stage-dot" />
                        <span>{{ labelInfo(stage).title }}</span>
                        <small v-if="stageTrailText(job, stage)">{{
                          stageTrailText(job, stage)
                        }}</small>
                      </li>
                    </ol>
                  </div>
                </article>
              </div>
              <div v-else class="rotta-board-column__empty">
                <Icon icon="i-lucide-check-circle-2" class="size-5" />
                <span>Sem clientes nesta etapa</span>
              </div>
            </article>
          </div>

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
                        class="rotta-history-toggle rotta-history-toggle--icon"
                        :aria-expanded="isHistoryExpanded(job)"
                        :aria-label="
                          isHistoryExpanded(job)
                            ? 'Ocultar trilha'
                            : 'Mostrar trilha'
                        "
                        :title="
                          isHistoryExpanded(job)
                            ? 'Ocultar trilha'
                            : 'Mostrar trilha'
                        "
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
                            'rotta-due': isDue(job) && !isHistoricalJob(job),
                          }"
                        >
                          {{ formatDate(job.scheduled_at) }}
                        </span>
                        <small
                          :class="{
                            'rotta-due': isDue(job) && !isHistoricalJob(job),
                          }"
                        >
                          {{
                            isHistoricalJob(job)
                              ? 'Último disparo registrado'
                              : countdownText(job)
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
                class="rotta-history-toggle rotta-history-toggle--mobile rotta-history-toggle--icon"
                :aria-expanded="isHistoryExpanded(job)"
                :aria-label="
                  isHistoryExpanded(job) ? 'Ocultar trilha' : 'Mostrar trilha'
                "
                :title="
                  isHistoryExpanded(job) ? 'Ocultar trilha' : 'Mostrar trilha'
                "
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
                      'rotta-due': isDue(job) && !isHistoricalJob(job),
                    }"
                  >
                    {{ formatDate(job.scheduled_at) }}
                  </span>
                  <small
                    :class="{
                      'rotta-due': isDue(job) && !isHistoricalJob(job),
                    }"
                  >
                    {{
                      isHistoricalJob(job)
                        ? 'Último disparo registrado'
                        : countdownText(job)
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
  flex-wrap: wrap;
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

.rotta-view-tabs {
  display: flex;
  flex: 1 1 100%;
  gap: 0.35rem;
  max-width: 100%;
  overflow-x: auto;
  scrollbar-width: thin;
}

.rotta-view-tabs button {
  display: inline-flex;
  align-items: center;
  flex: 0 0 auto;
  gap: 0.4rem;
  min-height: 2rem;
  padding: 0.35rem 0.65rem;
  @apply text-n-slate-11 bg-n-alpha-1 border border-n-weak;
  font-size: 0.72rem;
  font-weight: 600;
  border-radius: 0.65rem;
  cursor: pointer;
  transition:
    background-color 120ms ease,
    border-color 120ms ease,
    color 120ms ease;
}

.rotta-view-tabs button:hover,
.rotta-view-tabs button:focus-visible {
  @apply text-n-blue-11 border-n-blue-7;
}

.rotta-view-tab--active {
  @apply text-n-blue-11 bg-n-blue-2 border-n-blue-7;
}

.rotta-view-tabs button span {
  min-width: 1.15rem;
  padding: 0.1rem 0.3rem;
  @apply text-n-slate-11 bg-n-solid-1;
  font-size: 0.65rem;
  text-align: center;
  border-radius: 999px;
}

.rotta-board {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(17rem, 1fr));
  gap: 0.75rem;
  align-items: start;
}

.rotta-board--trails {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.rotta-board-column {
  display: flex;
  min-width: 0;
  min-height: 15rem;
  flex-direction: column;
  @apply bg-n-solid-2 border border-n-weak;
  border-radius: 1rem;
}

.rotta-board-column--ready {
  @apply border-n-teal-7;
}

.rotta-board-column--attention {
  @apply border-n-ruby-7;
}

.rotta-board-column__header {
  padding: 0.8rem 0.85rem 0.7rem;
  @apply border-b border-n-weak;
}

.rotta-board-column__title {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  @apply text-n-slate-12;
}

.rotta-board-column__title h3 {
  flex: 1;
  margin: 0;
  font-size: 0.8rem;
  font-weight: 700;
}

.rotta-board-column__title > span {
  min-width: 1.45rem;
  padding: 0.12rem 0.35rem;
  @apply text-n-slate-11 bg-n-alpha-1;
  font-size: 0.68rem;
  text-align: center;
  border-radius: 999px;
}

.rotta-board-column__header p {
  margin: 0.35rem 0 0;
  @apply text-n-slate-11;
  font-size: 0.68rem;
  line-height: 1.35;
}

.rotta-board-column__stages {
  display: flex;
  flex-wrap: wrap;
  gap: 0.3rem;
  margin-top: 0.65rem;
}

.rotta-stage-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  max-width: 100%;
  padding: 0.18rem 0.4rem;
  overflow: hidden;
  @apply text-n-slate-11 bg-n-alpha-1;
  border-radius: 0.35rem;
  font-size: 0.62rem;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-stage-chip::before {
  width: 0.35rem;
  height: 0.35rem;
  flex: 0 0 auto;
  background: var(--stage-color);
  border-radius: 999px;
  content: '';
}

.rotta-board-column__body {
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
  padding: 0.6rem;
}

.rotta-board-column__empty {
  display: flex;
  min-height: 9rem;
  flex: 1;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  padding: 1rem;
  @apply text-n-slate-10;
  font-size: 0.7rem;
  text-align: center;
}

.rotta-board-card {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
  padding: 0.75rem;
  @apply bg-n-solid-1 border border-n-weak;
  border-radius: 0.85rem;
  cursor: pointer;
  transition:
    border-color 120ms ease,
    box-shadow 120ms ease,
    transform 120ms ease;
}

.rotta-board-card:hover,
.rotta-board-card:focus-visible,
.rotta-board-card--expanded {
  @apply border-n-blue-7;
  box-shadow: 0 5px 18px rgb(15 23 42 / 9%);
}

.rotta-board-card:focus-visible {
  outline: 2px solid rgb(var(--blue-7));
  outline-offset: 2px;
}

.rotta-board-card__topline,
.rotta-board-card__labels,
.rotta-board-card__footer,
.rotta-board-card__schedule-main,
.rotta-board-card__schedule-meta,
.rotta-board-card__compact-meta {
  display: flex;
  align-items: center;
}

.rotta-board-card__topline,
.rotta-board-card__footer,
.rotta-board-card__compact-meta {
  justify-content: space-between;
  gap: 0.5rem;
}

.rotta-client--board {
  min-width: 0;
  flex: 1;
}

.rotta-board-card__labels {
  flex-wrap: wrap;
  gap: 0.4rem;
}

.rotta-board-card__next {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  max-width: 100%;
  @apply text-n-slate-11;
  font-size: 0.7rem;
}

.rotta-board-card__compact-meta {
  @apply text-n-slate-11;
  font-size: 0.67rem;
}

.rotta-board-card__compact-meta span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-board-card__schedule {
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  padding: 0.55rem;
  @apply bg-n-alpha-1;
  border-radius: 0.65rem;
}

.rotta-board-card__schedule-main {
  align-items: flex-start;
  gap: 0.45rem;
}

.rotta-board-card__schedule-main > div {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 0.15rem;
}

.rotta-board-card__schedule-main strong {
  @apply text-n-slate-12;
  font-size: 0.76rem;
}

.rotta-board-card__schedule-main small,
.rotta-board-card__schedule-meta {
  @apply text-n-slate-11;
  font-size: 0.67rem;
}

.rotta-board-card__schedule-meta {
  flex-wrap: wrap;
  gap: 0.3rem;
}

.rotta-board-card__schedule-meta span {
  padding: 0.15rem 0.35rem;
  @apply bg-n-solid-2;
  border-radius: 0.35rem;
}

.rotta-board-card__actions {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.35rem;
  padding-top: 0.1rem;
  @apply border-t border-n-weak;
}

.rotta-board-card__actions :deep(button) {
  flex: 0 0 auto;
}

.rotta-board-card__footer .rotta-delivery-evidence {
  flex: 1;
  text-align: right;
}

.rotta-hours-input {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  @apply text-n-slate-11;
  font-size: 0.66rem;
}

.rotta-hours-input input {
  width: 3.35rem;
  height: 2rem;
  padding: 0 0.35rem;
  @apply text-n-slate-12 bg-n-solid-1 border border-n-strong;
  font-size: 0.72rem;
  border-radius: 0.45rem;
}

.rotta-board-card__hint {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  flex: 1;
  @apply text-n-slate-11;
  font-size: 0.68rem;
}

.rotta-history--board {
  margin: -0.1rem -0.1rem 0;
  padding: 0.7rem;
  @apply bg-n-alpha-1;
  border-radius: 0.65rem;
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

.rotta-history-toggle--icon {
  width: 1.7rem;
  height: 1.7rem;
  justify-content: center;
  margin-top: 0;
  padding: 0;
  @apply bg-n-alpha-1 border border-n-weak;
  border-radius: 0.5rem;
}

.rotta-history-toggle--icon:hover,
.rotta-history-toggle--icon:focus-visible {
  @apply bg-n-blue-2 border-n-blue-7;
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

/* The kanban is the single operational surface; the legacy table markup is
   kept below temporarily so the migration remains easy to review. */
.rotta-queue__desktop,
.rotta-queue__mobile {
  display: none !important;
}

@media (max-width: 1023px) {
  .rotta-board {
    grid-template-columns: repeat(2, minmax(16rem, 1fr));
  }
}

@media (max-width: 640px) {
  .rotta-board {
    grid-template-columns: minmax(0, 1fr);
  }

  .rotta-view-tabs {
    margin-inline: -0.25rem;
    padding-inline: 0.25rem;
  }

  .rotta-board-card__actions :deep(button) {
    flex: 1 1 auto;
  }

  .rotta-board-card {
    gap: 0.6rem;
    padding: 0.65rem;
  }

  .rotta-board-card__footer .rotta-delivery-evidence {
    text-align: left;
  }
}
</style>
