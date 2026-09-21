<!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import rottaFollowUpAPI from 'dashboard/api/rottaFollowUp';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import {
  CONFIGURED_DELAY_HOURS,
  countdownPartsFor,
  canonicalFollowUpStage,
  CONTACT_TRAIL_STAGES,
  currentStageFor,
  delayHoursFor,
  dispatchWindowFor,
  BUDGET_TRAIL_STAGES,
  FOLLOW_UP_STAGE_TITLES,
  followUpTrailForJob,
  followUpTrailForStage,
  jobBelongsToFollowUpView,
  effectiveDispatchAt,
  compactDispatchText,
  isArchivedStage,
  isHistoricalJob,
  isWithinDispatchWindow,
  isStaleHistoricalJob,
  deduplicateFollowUpJobs,
  isFollowUpForToday,
  isFollowUpOverdue,
  operationalFollowUpJobs,
  reconcilePendingEnrollments,
  orderedFollowUpStages,
  displayTrailStagesFor,
  nextFollowUpStageFor,
} from './followUpHelpers';
import { createFollowUpRefreshScheduler } from './followUpRefreshScheduler';

const TIMEZONE = 'America/Sao_Paulo';
const router = useRouter();
const { uiSettings, updateUISettings } = useUISettings();
const initialBoardMode =
  uiSettings.value?.rotta_follow_up_board_mode || 'board';

const labelMeta = {
  'primeiro-contato': { title: 'Primeiro contato', color: '#16a34a' },
  'segundo-contato': { title: 'Segundo contato', color: '#f59e0b' },
  'terceiro-contato': { title: 'Terceiro contato', color: '#3b82f6' },
  'ultimo-contato': { title: 'Quarto contato', color: '#dc2626' },
  'orcamento-feito': { title: 'Orçamento feito ✅', color: '#16a34a' },
  'orcamento-tentativa-2': {
    title: 'Segundo orçamento',
    color: '#f59e0b',
  },
  'orcamento-tentativa-3': {
    title: 'Terceiro orçamento',
    color: '#3b82f6',
  },
  'orcamento-tentativa-4': {
    title: 'Quarto orçamento',
    color: '#dc2626',
  },
  'orcamento-5-dias': { title: 'Orçamento 5 dias', color: '#06b6d4' },
  'orcamento-10-dias': { title: 'Orçamento 10 dias', color: '#4f46e5' },
  'orcamento-15-dias': { title: 'Orçamento 15 dias', color: '#7c3aed' },
  'kelvin-caio': { title: 'KELVIN / CAIO', color: '#c026d3' },
  arquivado: { title: 'Arquivado', color: '#991b1b' },
};

const jobs = ref([]);
const apiLabels = ref({});
const responseMeta = ref({});
const isLoading = ref(false);
const busyJobId = ref('');
const searchQuery = ref('');
const selectedStage = ref(
  initialBoardMode === 'stage' ? 'primeiro-contato' : 'all'
);
const timezone = ref(TIMEZONE);
const now = ref(Date.now());
const lastSyncedAt = ref(null);
const expandedJobs = ref(new Set());
const pendingEnrollments = ref([]);
const selectedView = ref('all');
const boardMode = ref(initialBoardMode);
const customHours = ref({});
const dispatchDialogRef = ref(null);
const pendingDispatchJob = ref(null);
const summaryPanel = ref(null);
let refreshTimer;
let clockTimer;
let refreshRequested = false;
let isMounted = false;
let loadQueue;
let openingConversationKey = '';
let refreshScheduler;

const REALTIME_REFRESH_DEBOUNCE_MS = 400;
// The n8n worker can update labels outside the browser's ActionCable stream.
// Keep a short reconciliation window so the board does not wait 30 seconds
// for an external worker transition while retaining the in-flight guard in
// loadQueue to avoid overlapping requests.
const QUEUE_RECONCILIATION_INTERVAL_MS = 5000;

const labelInfo = slug => {
  const canonicalStage = canonicalFollowUpStage(slug);
  const fallback = String(slug || 'outros')
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
  return {
    title:
      FOLLOW_UP_STAGE_TITLES[canonicalStage] ||
      labelMeta[canonicalStage]?.title ||
      apiLabels.value[slug] ||
      apiLabels.value[canonicalStage] ||
      labelMeta[slug]?.title ||
      fallback,
    color:
      labelMeta[canonicalStage]?.color || labelMeta[slug]?.color || '#64748b',
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

const contactTrail = CONTACT_TRAIL_STAGES;
const budgetTrail = BUDGET_TRAIL_STAGES;

const displayStageFor = job => {
  return canonicalFollowUpStage(currentStage(job));
};

const trailFor = job => {
  const trail = followUpTrailForJob(job);
  return displayTrailStagesFor(trail);
};

const nextStageFor = nextFollowUpStageFor;

const pendingJobKey = item =>
  `${item.conversation_id}:${canonicalFollowUpStage(item.label)}`;

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
  if (status === 'sent') return 'Enviado';
  return 'Mensagem criada no Chatwoot';
};

const evidenceConfirmationText = job => {
  const status = String(deliveryEvidence(job)?.status || '').toLowerCase();
  if (status === 'read') return 'Confirmação de leitura recebida';
  if (status === 'delivered') return 'Confirmação de entrega recebida';
  if (status === 'sent') return 'Aguardando confirmação de envio';
  return 'Envio registrado';
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

const reconciledJobs = computed(() =>
  deduplicateFollowUpJobs(jobs.value.filter(job => !isStaleHistoricalJob(job)))
);

const queueJobs = computed(() => {
  const returnedKeys = new Set(
    reconciledJobs.value.map(
      job => `${job.conversation_id}:${currentStage(job)}`
    )
  );
  const waiting = pendingJobs.value.filter(
    job => !returnedKeys.has(`${job.conversation_id}:${currentStage(job)}`)
  );
  return [...waiting, ...reconciledJobs.value];
});

// Historical dispatch rows are audit records, not members of the current
// operational queue. Keeping them in the Kanban made one conversation appear
// in both its previous and current stages (and inflated stage counters).
// The active job already carries the worker history used by the expanded
// timeline, so the audit trail remains available without a ghost card.
const operationalJobs = computed(() =>
  operationalFollowUpJobs(queueJobs.value)
);

const counts = computed(() =>
  operationalJobs.value.reduce((result, job) => {
    const stage = displayStageFor(job);
    if (stage && !isArchivedStage(stage)) {
      result[stage] = (result[stage] || 0) + 1;
    }
    return result;
  }, {})
);

const trailViews = [
  {
    key: 'all',
    title: 'Todos',
    description: 'Todas as trilhas de follow-up em sequência.',
    icon: 'i-lucide-layout-grid',
    stages: [...CONTACT_TRAIL_STAGES, ...BUDGET_TRAIL_STAGES],
  },
  {
    key: 'contact',
    title: 'Trilha de contato',
    description: 'Cadência de relacionamento antes do orçamento.',
    icon: 'i-lucide-route',
    stages: contactTrail,
  },
  {
    key: 'budget',
    title: 'Trilha de orçamento',
    description: 'Tentativas e lembretes para converter o orçamento.',
    icon: 'i-lucide-badge-dollar-sign',
    stages: budgetTrail,
  },
];

const legacyStagesHiddenFromFilter = new Set([
  'contato-instantaneo',
  'orcamento-instantaneo',
  'clientes-fechados',
]);

const selectedTrailView = computed(
  () =>
    trailViews.find(view => view.key === selectedView.value) || trailViews[0]
);

const trailViewForJob = followUpTrailForJob;

const stageOptions = computed(() => {
  const values = new Set([
    ...selectedTrailView.value.stages,
    ...operationalJobs.value
      .filter(job => jobBelongsToFollowUpView(job, selectedView.value))
      .map(displayStageFor)
      .filter(stage => stage && !legacyStagesHiddenFromFilter.has(stage)),
  ]);
  return orderedFollowUpStages([...values]);
});

const trailColumns = computed(() => {
  const configuredStages = selectedTrailView.value.stages;
  const additionalStages = orderedFollowUpStages(
    operationalJobs.value
      .filter(job => jobBelongsToFollowUpView(job, selectedView.value))
      .map(displayStageFor)
      .filter(
        stage =>
          stage &&
          !configuredStages.includes(stage) &&
          !followUpTrailForStage(stage) &&
          !isArchivedStage(stage) &&
          !legacyStagesHiddenFromFilter.has(stage)
      )
  );
  const columns = configuredStages.map(stage => ({
    key: `stage-${stage}`,
    title: labelInfo(stage).title,
    description: selectedTrailView.value.title,
    icon: selectedTrailView.value.icon,
    stages: [stage],
    stageKeys: [stage],
    showStageChips: false,
  }));
  if (additionalStages.length) {
    columns.push({
      key: 'other',
      title: 'Outras etapas',
      description: 'Etiquetas adicionais mantidas no fluxo.',
      icon: 'i-lucide-tags',
      stages: additionalStages,
      stageKeys: additionalStages,
      showStageChips: true,
    });
  }
  return columns.map(column => ({
    ...column,
    stageKeys: column.stageKeys || column.stages,
  }));
});

const activeJobs = computed(() =>
  operationalJobs.value.filter(job => Boolean(trailViewForJob(job)))
);

const viewCount = view => {
  return operationalJobs.value.filter(job =>
    jobBelongsToFollowUpView(job, view)
  ).length;
};

const viewOptions = computed(() => trailViews);

const visibleColumns = computed(() => {
  if (boardMode.value !== 'stage' || selectedStage.value === 'all') {
    return trailColumns.value;
  }
  return trailColumns.value.filter(column =>
    column.stageKeys.includes(selectedStage.value)
  );
});

const filteredJobs = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  return operationalJobs.value.filter(job => {
    const matchesView = jobBelongsToFollowUpView(job, selectedView.value);
    const displayStage = displayStageFor(job);
    const matchesStage =
      selectedStage.value === 'all' || displayStage === selectedStage.value;
    const content = [
      job.customer_name,
      job.phone,
      displayStage,
      nextStageFor(job),
      labelInfo(displayStageFor(job)).title,
      labelInfo(nextStageFor(job)).title,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    return (
      matchesView &&
      !isArchivedStage(displayStage) &&
      matchesStage &&
      (!query || content.includes(query))
    );
  });
});

const nextFollowUpTimestamp = job => {
  const target = effectiveDispatchAt(
    job?.scheduled_at,
    now.value,
    dispatchWindow(job)
  );
  return Number.isFinite(target) ? target : Number.MAX_SAFE_INTEGER;
};

const orderedFilteredJobs = computed(() =>
  [...filteredJobs.value].sort((left, right) => {
    const targetDifference =
      nextFollowUpTimestamp(left) - nextFollowUpTimestamp(right);
    if (targetDifference !== 0) return targetDifference;
    return labelInfo(currentStage(left)).title.localeCompare(
      labelInfo(currentStage(right)).title,
      'pt-BR'
    );
  })
);

watch(selectedView, () => {
  selectedStage.value = 'all';
});

watch(boardMode, value => {
  updateUISettings({ rotta_follow_up_board_mode: value });
  if (value === 'stage' && selectedStage.value === 'all') {
    selectedStage.value = stageOptions.value[0] || 'all';
  }
});

const selectStage = stage => {
  selectedStage.value = stage;
  boardMode.value = 'stage';
};

const jobsForColumn = columnKey => {
  const groupedColumn = trailColumns.value.find(
    column => column.key === columnKey
  );
  const jobsInColumn = orderedFilteredJobs.value.filter(job => {
    const stage = displayStageFor(job);
    return groupedColumn?.stageKeys
      ? groupedColumn.stageKeys.includes(stage)
      : false;
  });

  if (!groupedColumn) return jobsInColumn;

  const stageOrder = new Map(
    groupedColumn.stageKeys.map((stage, index) => [stage, index])
  );
  return [...jobsInColumn].sort((left, right) => {
    const targetDifference =
      nextFollowUpTimestamp(left) - nextFollowUpTimestamp(right);
    if (targetDifference !== 0) return targetDifference;
    return (
      (stageOrder.get(displayStageFor(left)) ?? Number.MAX_SAFE_INTEGER) -
      (stageOrder.get(displayStageFor(right)) ?? Number.MAX_SAFE_INTEGER)
    );
  });
};

const todayCount = computed(
  () =>
    activeJobs.value.filter(job =>
      isFollowUpForToday(job, now.value, responseMeta.value)
    ).length
);

const overdueJobs = computed(() =>
  activeJobs.value.filter(job =>
    isFollowUpOverdue(job, now.value, responseMeta.value)
  )
);

const overdueCount = computed(() => overdueJobs.value.length);

const allCount = computed(() => activeJobs.value.length);

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
  if (displayStageFor(job) === stage) return 'atual';
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
  if (metadata.hours === null) return 'Intervalo não informado';
  if (metadata.hours === 0) return 'Imediato';
  return `Intervalo: ${metadata.hours} horas`;
};

const windowText = job => {
  const window = dispatchWindow(job);
  return `Horário permitido: ${window.start}–${window.end}`;
};

const scheduleText = job => {
  if (job.pending_enrollment) {
    return job.status === 'sync_failed'
      ? 'Etiqueta não confirmada'
      : 'Atualizando etiqueta…';
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
    pending: 'Aguardando envio',
    processing: 'Atualizando',
    syncing: 'Atualizando etiqueta',
    sync_failed: 'Etiqueta não confirmada',
    failed_send: 'Envio não concluído',
    failed_labels: 'Etiqueta não atualizada',
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

const firstReadableError = job => {
  const rawError = [
    job?.last_error,
    job?.error_message,
    job?.failure_reason,
    job?.error,
    job?.reason,
    job?.details,
  ].find(value => value !== undefined && value !== null && value !== '');

  if (!rawError) return '';
  if (typeof rawError === 'string') return rawError.trim();
  if (typeof rawError?.message === 'string') return rawError.message.trim();

  try {
    return JSON.stringify(rawError);
  } catch {
    return String(rawError);
  }
};

const isOutsideDispatchWindow = job => {
  if (
    isHistoricalJob(job) ||
    job?.pending_enrollment ||
    deliveryEvidence(job)?.message_id ||
    String(job?.status || '').startsWith('failed')
  ) {
    return false;
  }

  const scheduledAt = new Date(job?.scheduled_at).getTime();
  return (
    Number.isFinite(scheduledAt) &&
    scheduledAt <= now.value &&
    !isWithinDispatchWindow(now.value, dispatchWindow(job))
  );
};

const followUpFeedback = job => {
  const error = firstReadableError(job);
  const hasFailed =
    String(job?.status || '').startsWith('failed') ||
    job?.status === 'sync_failed';

  if (hasFailed) {
    return {
      tone: 'error',
      icon: 'i-lucide-circle-alert',
      title: statusText(job.status, job),
      detail:
        error ||
        (job.status === 'sync_failed'
          ? 'A etiqueta ainda não foi confirmada. Verifique a conexão do envio.'
          : 'Não foi possível identificar a causa. Tente novamente.'),
    };
  }

  if (isOutsideDispatchWindow(job)) {
    return {
      tone: 'waiting',
      icon: 'i-lucide-moon-star',
      title: 'Aguardando horário comercial',
      detail: `Envio liberado entre ${windowText(job)}. Próxima tentativa: ${scheduleText(job)}.`,
    };
  }

  return null;
};

const failureJobs = computed(() =>
  operationalJobs.value.filter(job => {
    const status = String(job?.status || '');
    return status === 'sync_failed' || status.startsWith('failed');
  })
);

const summaryPanelJobs = computed(() => {
  const panelJobs =
    summaryPanel.value === 'overdue' ? overdueJobs.value : failureJobs.value;
  return [...panelJobs].sort((left, right) => {
    const targetDifference =
      nextFollowUpTimestamp(left) - nextFollowUpTimestamp(right);
    if (targetDifference !== 0) return targetDifference;
    return String(left?.customer_name || '').localeCompare(
      String(right?.customer_name || ''),
      'pt-BR'
    );
  });
});

const summaryPanelTitle = computed(() =>
  summaryPanel.value === 'overdue'
    ? 'Follow-ups em atraso'
    : 'Falhas de follow-up'
);

const summaryPanelDescription = computed(() =>
  summaryPanel.value === 'overdue'
    ? 'Clientes cujo horário chegou, mas aguardam a próxima janela permitida.'
    : 'Ocorrências atuais informadas pelo fluxo de disparo.'
);

const summaryPanelEmptyTitle = computed(() =>
  summaryPanel.value === 'overdue'
    ? 'Nenhum follow-up em atraso'
    : 'Nenhuma falha atual'
);

const summaryPanelEmptyDescription = computed(() =>
  summaryPanel.value === 'overdue'
    ? 'Todos os envios estão dentro do horário permitido.'
    : 'Os disparos ativos não reportaram erros.'
);

const toggleSummaryPanel = panel => {
  summaryPanel.value = summaryPanel.value === panel ? null : panel;
};

const closeSummaryPanel = () => {
  summaryPanel.value = null;
};

const selectAllFollowUps = () => {
  selectedView.value = 'all';
  selectedStage.value = 'all';
  summaryPanel.value = null;
};

const exactFailureText = job =>
  firstReadableError(job) || 'O fluxo não informou o erro exato.';

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

  const previousChanges =
    data?.previous_changes ||
    data?.changed_attributes ||
    data?.changedAttributes;
  const changedLabelValue =
    previousChanges && typeof previousChanges === 'object'
      ? previousChanges.label_list ||
        previousChanges.cached_label_list ||
        previousChanges.labels
      : undefined;
  const changedCurrentValue = Array.isArray(changedLabelValue)
    ? changedLabelValue[1]
    : (changedLabelValue?.current_value ?? changedLabelValue?.currentValue);
  const hasLabelSnapshot =
    data?.labels !== undefined ||
    conversation.labels !== undefined ||
    data?.label_list !== undefined ||
    changedLabelValue !== undefined;
  if (!hasLabelSnapshot) return;

  const labels =
    data?.labels ??
    conversation.labels ??
    data?.label_list ??
    changedCurrentValue ??
    [];
  const labelValues = Array.isArray(labels)
    ? labels
    : String(labels || '')
        .split(',')
        .map(label => label.trim())
        .filter(Boolean);
  const linkedLabels = labelValues
    .map(slugForLabel)
    .filter(label => linkedLabelSlugs.has(label));
  const linkedLabelSet = new Set(linkedLabels);

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
    pendingEnrollments.value
      .filter(
        item =>
          String(item.conversation_id) !== String(conversationId) ||
          linkedLabelSet.has(canonicalFollowUpStage(item.label))
      )
      .map(item => [pendingJobKey(item), item])
  );
  linkedLabels.forEach(label => {
    const item = { ...details, label };
    current.set(pendingJobKey(item), item);
  });
  pendingEnrollments.value = [...current.values()];
};

function scheduleRealtimeRefresh(data) {
  if (!isMounted) return;
  registerPendingEnrollment(data);
  refreshScheduler.schedule();
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
    apiLabels.value = body.labels || {};
    timezone.value = body.timezone || TIMEZONE;
    responseMeta.value = {
      ...(body.meta || {}),
      ...(body.config || {}),
      timezone: body.timezone || body.meta?.timezone || TIMEZONE,
    };
    pendingEnrollments.value = reconcilePendingEnrollments(
      pendingEnrollments.value,
      reconciledJobs.value,
      now.value
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
  if (busyJobId.value === job.job_id) return;
  busyJobId.value = job.job_id;
  try {
    const payload = {
      action,
      job_id: job.job_id,
      conversation_id: job.conversation_id,
    };
    if (hours !== undefined) payload.hours = hours;
    if (action === 'remove_label') {
      payload.conversation_id = job.conversation_id;
      payload.label = canonicalFollowUpStage(currentStage(job));
    }
    await request(payload);
    pendingEnrollments.value = pendingEnrollments.value.filter(
      item =>
        pendingJobKey(item) !==
        `${job.conversation_id}:${canonicalFollowUpStage(currentStage(job))}`
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

const shiftOneDay = (job, direction) => {
  runAction(job, direction === 'earlier' ? 'advance' : 'delay', 24);
};

const requestDispatchNow = job => {
  pendingDispatchJob.value = job;
  dispatchDialogRef.value?.open();
};

const confirmDispatchNow = async () => {
  const job = pendingDispatchJob.value;
  if (!job) return;
  await runAction(job, 'dispatch_now');
  dispatchDialogRef.value?.close();
  pendingDispatchJob.value = null;
};

const openConversation = job => {
  const accountId = job.account_id;
  const conversationId = job.conversation_id;
  if (!accountId || !conversationId) return;

  const conversationKey = `${accountId}:${conversationId}`;
  if (openingConversationKey === conversationKey) return;
  openingConversationKey = conversationKey;

  router
    .push({
      name: 'inbox_conversation',
      params: { accountId, conversation_id: conversationId },
    })
    .finally(() => {
      if (openingConversationKey === conversationKey) {
        openingConversationKey = '';
      }
    });
};

onMounted(async () => {
  isMounted = true;
  refreshScheduler = createFollowUpRefreshScheduler({
    refresh: () => loadQueue(),
    debounceMs: REALTIME_REFRESH_DEBOUNCE_MS,
  });
  emitter.on(BUS_EVENTS.ROTTA_FOLLOW_UP_REFRESH, scheduleRealtimeRefresh);
  emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT, scheduleRealtimeRefresh);
  await loadQueue();
  clockTimer = window.setInterval(() => {
    now.value = Date.now();
  }, 1000);
  refreshTimer = window.setInterval(
    loadQueue,
    QUEUE_RECONCILIATION_INTERVAL_MS
  );
});

onUnmounted(() => {
  isMounted = false;
  emitter.off(BUS_EVENTS.ROTTA_FOLLOW_UP_REFRESH, scheduleRealtimeRefresh);
  emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT, scheduleRealtimeRefresh);
  window.clearInterval(clockTimer);
  window.clearInterval(refreshTimer);
  refreshScheduler?.dispose();
});
</script>

<template>
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text -->
  <SettingsLayout>
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        title="Follow-up da Rotta"
        description="Acompanhe os envios por etiqueta, data e horário."
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
      <section class="rotta-follow-up" aria-label="Resumo dos follow-ups">
        <div class="rotta-summary-grid">
          <button
            type="button"
            class="rotta-summary-card rotta-summary-card--all"
            :class="{
              'rotta-summary-card--all-active':
                selectedView === 'all' && selectedStage === 'all',
            }"
            aria-label="Mostrar todos os follow-ups ativos"
            @click="selectAllFollowUps"
          >
            <span>Todos</span>
            <strong>{{ allCount }}</strong>
            <small>follow-ups ativos em todas as etapas</small>
          </button>
          <article class="rotta-summary-card rotta-summary-card--today">
            <span>Para hoje</span>
            <strong>{{ todayCount }}</strong>
            <small>follow-ups com envio previsto para hoje</small>
          </article>
          <button
            type="button"
            class="rotta-summary-card rotta-summary-card--overdue"
            :class="{
              'rotta-summary-card--overdue-active': summaryPanel === 'overdue',
            }"
            :aria-expanded="summaryPanel === 'overdue'"
            aria-controls="rotta-follow-up-summary-panel"
            aria-label="Mostrar follow-ups em atraso"
            @click="toggleSummaryPanel('overdue')"
          >
            <span>Em atraso</span>
            <strong>{{ overdueCount }}</strong>
            <small>aguardando o próximo horário permitido</small>
          </button>
          <button
            type="button"
            class="rotta-summary-card rotta-summary-card--failures"
            :class="{
              'rotta-summary-card--failures-active':
                summaryPanel === 'failures',
            }"
            :aria-expanded="summaryPanel === 'failures'"
            aria-controls="rotta-follow-up-summary-panel"
            aria-label="Mostrar falhas do follow-up"
            @click="toggleSummaryPanel('failures')"
          >
            <span>Falhas</span>
            <strong>{{ failureJobs.length }}</strong>
            <small>
              {{
                failureJobs.length
                  ? 'ver clientes e motivos'
                  : 'nenhuma ocorrência'
              }}
            </small>
          </button>
        </div>

        <section
          v-if="summaryPanel"
          id="rotta-follow-up-summary-panel"
          class="rotta-failures rotta-summary-panel"
          :class="{
            'rotta-summary-panel--overdue': summaryPanel === 'overdue',
          }"
          aria-labelledby="rotta-follow-up-summary-panel-title"
        >
          <header class="rotta-failures__header">
            <div>
              <h2 id="rotta-follow-up-summary-panel-title">
                {{ summaryPanelTitle }}
              </h2>
              <p>{{ summaryPanelDescription }}</p>
            </div>
            <Button
              label="Fechar"
              icon="i-lucide-x"
              size="sm"
              slate
              ghost
              @click="closeSummaryPanel"
            />
          </header>

          <div v-if="summaryPanelJobs.length" class="rotta-failures__list">
            <article
              v-for="job in summaryPanelJobs"
              :key="`${summaryPanel}-${job.job_id}`"
              class="rotta-failure-row"
            >
              <button
                type="button"
                class="rotta-failure-row__client"
                @click="openConversation(job)"
              >
                <strong>{{ job.customer_name || 'Cliente sem nome' }}</strong>
                <span>{{ job.phone || 'Telefone não informado' }}</span>
              </button>
              <div class="rotta-failure-row__context">
                <span
                  class="rotta-label-pill"
                  :style="{
                    '--label-color': labelInfo(displayStageFor(job)).color,
                  }"
                >
                  {{ labelInfo(displayStageFor(job)).title }}
                </span>
                <small>{{ formatDate(job.scheduled_at) }}</small>
              </div>
              <div class="rotta-failure-row__reason">
                <span
                  class="rotta-status"
                  :class="statusClass(job.status, job)"
                >
                  {{ statusText(job.status, job) }}
                </span>
                <p v-if="summaryPanel === 'failures'">
                  {{ exactFailureText(job) }}
                </p>
                <p v-else>
                  {{ countdownText(job) }} ·
                  {{ windowText(job) }}
                </p>
              </div>
              <Button
                label="Abrir conversa"
                icon="i-lucide-arrow-up-right"
                size="sm"
                slate
                ghost
                @click="openConversation(job)"
              />
            </article>
          </div>
          <div v-else class="rotta-failures__empty" role="status">
            <Icon
              :icon="
                summaryPanel === 'overdue'
                  ? 'i-lucide-clock-check'
                  : 'i-lucide-circle-check'
              "
              class="size-5"
            />
            <div>
              <strong>{{ summaryPanelEmptyTitle }}</strong>
              <span>{{ summaryPanelEmptyDescription }}</span>
            </div>
          </div>
        </section>

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
              · horário permitido {{ dispatchWindow({}).start }}–{{
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
          <div
            class="rotta-layout-picker"
            role="group"
            aria-label="Modelo do quadro"
          >
            <span>Layout</span>
            <button
              v-for="mode in [
                { key: 'board', label: 'Quadro', icon: 'i-lucide-columns-3' },
                {
                  key: 'stage',
                  label: 'Etapa em foco',
                  icon: 'i-lucide-focus',
                },
                {
                  key: 'compact',
                  label: 'Lista compacta',
                  icon: 'i-lucide-list',
                },
              ]"
              :key="mode.key"
              type="button"
              :class="{
                'rotta-layout-picker__button--active': boardMode === mode.key,
              }"
              :aria-pressed="boardMode === mode.key"
              @click="boardMode = mode.key"
            >
              <Icon :icon="mode.icon" class="size-4" />
              {{ mode.label }}
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
          <div
            v-if="boardMode === 'stage'"
            class="rotta-stage-filter"
            aria-label="Escolha rápida de etapa"
          >
            <button
              v-for="stage in stageOptions"
              :key="`focus-${stage}`"
              type="button"
              :class="{
                'rotta-stage-filter__button--active': selectedStage === stage,
              }"
              :style="{ '--stage-color': labelInfo(stage).color }"
              @click="selectStage(stage)"
            >
              {{ labelInfo(stage).title }}
              <span>{{ counts[stage] || 0 }}</span>
            </button>
          </div>
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
            v-if="boardMode !== 'compact'"
            class="rotta-board rotta-board--trails"
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
                  v-if="column.showStageChips && column.stageKeys"
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
                        '--label-color': labelInfo(displayStageFor(job)).color,
                      }"
                    >
                      {{ labelInfo(displayStageFor(job)).title }}
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
                          class="rotta-board-card__countdown"
                          :class="{
                            'rotta-board-card__countdown--ready': isDue(job),
                          }"
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
                          >O acompanhamento aparecerá aqui assim que a etiqueta
                          for confirmada</small
                        >
                      </div>
                    </div>
                    <div class="rotta-board-card__schedule-meta">
                      <span>{{ delayText(job) }}</span>
                      <span>{{ windowText(job) }}</span>
                    </div>
                  </div>

                  <div v-else class="rotta-board-card__compact-meta">
                    <span
                      class="rotta-board-card__compact-schedule"
                      :title="scheduleText(job)"
                    >
                      <Icon icon="i-lucide-clock-3" class="size-3.5" />
                      <span>{{
                        compactDispatchText(job, now, responseMeta)
                      }}</span>
                    </span>
                    <span
                      class="rotta-board-card__compact-status"
                      :class="statusClass(job.status, job)"
                    >
                      {{ statusText(job.status, job) }}
                    </span>
                  </div>

                  <div
                    v-if="followUpFeedback(job)"
                    class="rotta-follow-up-feedback"
                    :class="`rotta-follow-up-feedback--${followUpFeedback(job).tone}`"
                    role="status"
                    aria-live="polite"
                  >
                    <Icon
                      :icon="followUpFeedback(job).icon"
                      class="rotta-follow-up-feedback__icon"
                    />
                    <div>
                      <strong>{{ followUpFeedback(job).title }}</strong>
                      <span>{{ followUpFeedback(job).detail }}</span>
                    </div>
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
                            ? 'Não foi possível confirmar a etiqueta'
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
                        @click="requestDispatchNow(job)"
                      />
                      <Button
                        label="−1 dia"
                        size="sm"
                        slate
                        ghost
                        :disabled="busyJobId === job.job_id"
                        @click="shiftOneDay(job, 'earlier')"
                      />
                      <Button
                        label="+1 dia"
                        size="sm"
                        slate
                        ghost
                        :disabled="busyJobId === job.job_id"
                        @click="shiftOneDay(job, 'later')"
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
                            ? `${labelInfo(displayStageFor(job)).title} · ${evidenceStatusText(job)} em ${formatDate(deliveryEvidence(job).created_at)} — ${evidenceConfirmationText(job)}`
                            : normaliseHistory(job).length
                              ? 'Etapas já enviadas'
                              : job.pending_enrollment
                                ? 'Etiqueta recebida; atualizando o acompanhamento'
                                : 'O histórico de envios ainda não está disponível'
                        }}
                      </span>
                    </div>
                    <ol class="rotta-stage-track">
                      <li
                        v-for="stage in trailFor(job)"
                        :key="`${job.job_id}-board-${stage}`"
                        :class="{
                          'rotta-stage--current':
                            displayStageFor(job) === stage,
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

          <div
            v-if="boardMode === 'compact'"
            class="rotta-queue__desktop rotta-queue__desktop--visible"
          >
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
                  <tr v-for="job in orderedFilteredJobs" :key="job.job_id">
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
                          '--label-color': labelInfo(displayStageFor(job))
                            .color,
                        }"
                      >
                        {{ labelInfo(displayStageFor(job)).title }}
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
                          {{ labelInfo(displayStageFor(job)).title }}</small
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
                        {{ labelInfo(displayStageFor(job)).title }} ·
                        {{ evidenceConfirmationText(job) }}
                      </small>
                      <div
                        v-if="followUpFeedback(job)"
                        class="rotta-follow-up-feedback rotta-follow-up-feedback--table"
                        :class="`rotta-follow-up-feedback--${followUpFeedback(job).tone}`"
                        role="status"
                      >
                        <Icon
                          :icon="followUpFeedback(job).icon"
                          class="rotta-follow-up-feedback__icon"
                        />
                        <div>
                          <strong>{{ followUpFeedback(job).title }}</strong>
                          <span>{{ followUpFeedback(job).detail }}</span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div v-if="!isHistoricalJob(job)" class="rotta-actions">
                        <Button
                          label="Agora"
                          size="sm"
                          teal
                          :is-loading="busyJobId === job.job_id"
                          @click="requestDispatchNow(job)"
                        />
                        <Button
                          v-tooltip.top="'Adiantar exatamente 24 horas'"
                          label="−1 dia"
                          size="sm"
                          slate
                          ghost
                          :disabled="busyJobId === job.job_id"
                          @click="shiftOneDay(job, 'earlier')"
                        />
                        <Button
                          v-tooltip.top="'Atrasar exatamente 24 horas'"
                          label="+1 dia"
                          size="sm"
                          slate
                          ghost
                          :disabled="busyJobId === job.job_id"
                          @click="shiftOneDay(job, 'later')"
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
                    v-for="job in orderedFilteredJobs"
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
                                ? `${labelInfo(displayStageFor(job)).title} · ${evidenceStatusText(job)} em ${formatDate(deliveryEvidence(job).created_at)} — ${evidenceConfirmationText(job)}`
                                : normaliseHistory(job).length
                                  ? 'Etapas já enviadas'
                                  : 'O histórico de envios ainda não está disponível'
                            }}
                          </span>
                        </div>
                        <ol class="rotta-stage-track">
                          <li
                            v-for="stage in trailFor(job)"
                            :key="`${job.job_id}-${stage}`"
                            :class="{
                              'rotta-stage--current':
                                displayStageFor(job) === stage,
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

          <div v-if="boardMode === 'compact'" class="rotta-queue__mobile">
            <article
              v-for="job in orderedFilteredJobs"
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
                  {{ labelInfo(displayStageFor(job)).title }} ·
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
                        ? `${labelInfo(displayStageFor(job)).title} · ${evidenceStatusText(job)} em ${formatDate(deliveryEvidence(job).created_at)} — ${evidenceConfirmationText(job)}`
                        : normaliseHistory(job).length
                          ? 'Etapas já enviadas'
                          : 'O histórico de envios ainda não está disponível'
                    }}
                  </span>
                </div>
                <ol class="rotta-stage-track">
                  <li
                    v-for="stage in trailFor(job)"
                    :key="`${job.job_id}-mobile-${stage}`"
                    :class="{
                      'rotta-stage--current': displayStageFor(job) === stage,
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
                    '--label-color': labelInfo(displayStageFor(job)).color,
                  }"
                >
                  {{ labelInfo(displayStageFor(job)).title }}
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
                    >Etiqueta:
                    {{ labelInfo(displayStageFor(job)).title }}</small
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
                v-if="followUpFeedback(job)"
                class="rotta-follow-up-feedback"
                :class="`rotta-follow-up-feedback--${followUpFeedback(job).tone}`"
                role="status"
                aria-live="polite"
              >
                <Icon
                  :icon="followUpFeedback(job).icon"
                  class="rotta-follow-up-feedback__icon"
                />
                <div>
                  <strong>{{ followUpFeedback(job).title }}</strong>
                  <span>{{ followUpFeedback(job).detail }}</span>
                </div>
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
                  @click="requestDispatchNow(job)"
                />
                <Button
                  label="−1 dia"
                  size="sm"
                  slate
                  ghost
                  :disabled="busyJobId === job.job_id"
                  @click="shiftOneDay(job, 'earlier')"
                />
                <Button
                  label="+1 dia"
                  size="sm"
                  slate
                  ghost
                  :disabled="busyJobId === job.job_id"
                  @click="shiftOneDay(job, 'later')"
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
        <Dialog
          ref="dispatchDialogRef"
          type="alert"
          title="Disparar follow-up agora?"
          confirm-button-label="Sim, disparar agora"
          cancel-button-label="Voltar"
          :is-loading="
            pendingDispatchJob && busyJobId === pendingDispatchJob.job_id
          "
          @confirm="confirmDispatchNow"
          @close="pendingDispatchJob = null"
        >
          <div v-if="pendingDispatchJob" class="rotta-dispatch-confirmation">
            <p>
              A mensagem da etapa
              <strong>{{
                labelInfo(displayStageFor(pendingDispatchJob)).title
              }}</strong>
              será enviada imediatamente para
              <strong>{{
                pendingDispatchJob.customer_name || 'este cliente'
              }}</strong
              >.
            </p>
            <p>
              Essa ação antecipa o horário programado e pode gerar comunicação
              externa no WhatsApp.
            </p>
          </div>
        </Dialog>
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

.rotta-layout-picker,
.rotta-stage-filter {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.rotta-layout-picker > span {
  color: var(--color-n-slate-11);
  font-size: 0.75rem;
  font-weight: 600;
}

.rotta-layout-picker button,
.rotta-stage-filter button {
  display: inline-flex;
  min-height: 2.5rem;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;
  border: 1px solid var(--color-n-weak);
  border-radius: 0.625rem;
  padding: 0.5rem 0.75rem;
  color: var(--color-n-slate-11);
  background: var(--color-n-alpha-2);
  font-size: 0.75rem;
  font-weight: 600;
  transition:
    border-color 120ms ease,
    background-color 120ms ease,
    color 120ms ease;
}

.rotta-layout-picker button:hover,
.rotta-layout-picker__button--active {
  border-color: var(--color-n-brand);
  color: var(--color-n-brand);
  background: var(--color-n-brand-alpha-2);
}

.rotta-stage-filter {
  width: 100%;
  padding-top: 0.25rem;
}

.rotta-stage-filter button {
  box-shadow: inset 0 2px 0 var(--stage-color);
}

.rotta-stage-filter button span {
  min-width: 1.25rem;
  border-radius: 999px;
  padding: 0.125rem 0.375rem;
  background: var(--color-n-alpha-3);
}

.rotta-stage-filter__button--active {
  border-color: var(--stage-color) !important;
  color: var(--color-n-slate-12) !important;
  background: color-mix(
    in srgb,
    var(--stage-color) 10%,
    transparent
  ) !important;
}

.rotta-dispatch-confirmation {
  display: grid;
  gap: 0.75rem;
  color: var(--color-n-slate-11);
  font-size: 0.875rem;
  line-height: 1.5;
}

.rotta-dispatch-confirmation strong {
  color: var(--color-n-slate-12);
}

@media (max-width: 767px) {
  .rotta-layout-picker {
    width: 100%;
  }

  .rotta-layout-picker > span {
    width: 100%;
  }

  .rotta-layout-picker button {
    flex: 1 1 8rem;
    min-height: 2.75rem;
  }

  .rotta-stage-filter {
    flex-wrap: nowrap;
    overflow-x: auto;
    padding-bottom: 0.25rem;
    scroll-snap-type: x proximity;
  }

  .rotta-stage-filter button {
    flex: 0 0 auto;
    min-height: 2.75rem;
    scroll-snap-align: start;
  }
}

.rotta-summary-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
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
  align-items: flex-start;
  gap: 0.15rem;
  padding: 1rem;
  text-align: start;
}

button.rotta-summary-card {
  width: 100%;
  color: inherit;
  cursor: pointer;
  transition:
    border-color 120ms ease,
    background-color 120ms ease;
}

button.rotta-summary-card:hover,
button.rotta-summary-card:focus-visible {
  @apply border-n-blue-7 bg-n-blue-2;
}

.rotta-summary-card--all-active,
button.rotta-summary-card--all:hover,
button.rotta-summary-card--all:focus-visible {
  @apply border-n-blue-7 bg-n-blue-2;
}

.rotta-summary-card--overdue-active,
button.rotta-summary-card--overdue:hover,
button.rotta-summary-card--overdue:focus-visible {
  @apply border-n-amber-7 bg-n-amber-2;
}

button.rotta-summary-card--failures:hover,
button.rotta-summary-card--failures:focus-visible,
.rotta-summary-card--failures-active {
  @apply border-n-ruby-7 bg-n-ruby-2;
}

button.rotta-summary-card:focus-visible {
  outline: 2px solid rgb(var(--ruby-7));
  outline-offset: 2px;
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

.rotta-summary-card--today strong,
.rotta-due {
  @apply text-n-teal-11;
}

.rotta-summary-card--all strong {
  @apply text-n-blue-11;
}

.rotta-summary-card--overdue strong {
  @apply text-n-amber-11;
}

.rotta-summary-card--failures strong {
  @apply text-n-ruby-11;
}

.rotta-failures {
  @apply bg-n-solid-2 border border-n-ruby-6;
  overflow: hidden;
  border-radius: 1rem;
}

.rotta-summary-panel--overdue {
  @apply border-n-amber-6;
}

.rotta-failures__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 1rem;
  @apply border-b border-n-weak;
}

.rotta-failures__header h2 {
  margin: 0;
  @apply text-n-slate-12;
  font-size: 0.9rem;
  font-weight: 600;
}

.rotta-failures__header p {
  margin: 0.2rem 0 0;
  @apply text-n-slate-11;
  font-size: 0.75rem;
}

.rotta-failures__list {
  display: grid;
}

.rotta-failure-row {
  display: grid;
  grid-template-columns:
    minmax(10rem, 1fr) minmax(10rem, 0.8fr) minmax(16rem, 2fr)
    auto;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  @apply border-b border-n-weak;
}

.rotta-failure-row:last-child {
  border-bottom: 0;
}

.rotta-failure-row__client {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.15rem;
  padding: 0;
  color: inherit;
  text-align: start;
  background: transparent;
  border: 0;
  cursor: pointer;
}

.rotta-failure-row__client strong,
.rotta-failure-row__client span {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-failure-row__client strong {
  @apply text-n-slate-12;
  font-size: 0.8rem;
}

.rotta-failure-row__client span,
.rotta-failure-row__context small {
  @apply text-n-slate-11;
  font-size: 0.7rem;
}

.rotta-failure-row__context,
.rotta-failure-row__reason {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.3rem;
}

.rotta-failure-row__reason p {
  max-width: 100%;
  margin: 0;
  @apply text-n-ruby-11;
  font-size: 0.72rem;
  line-height: 1.35;
  overflow-wrap: anywhere;
}

.rotta-failures__empty {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 1rem;
  @apply text-n-teal-11;
}

.rotta-failures__empty > div {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.rotta-failures__empty strong {
  font-size: 0.8rem;
}

.rotta-failures__empty span {
  font-size: 0.72rem;
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
  display: grid;
  grid-template-columns: repeat(3, minmax(12rem, 1fr));
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
  min-height: 3.25rem;
  justify-content: center;
  padding: 0.7rem 1rem;
  @apply text-n-slate-11 bg-n-alpha-1 border border-n-weak;
  font-size: 0.9rem;
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
  min-width: 1.45rem;
  padding: 0.15rem 0.4rem;
  @apply text-n-slate-11 bg-n-solid-1;
  font-size: 0.72rem;
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
  grid-auto-flow: column;
  grid-auto-columns: minmax(16rem, 18rem);
  grid-template-columns: none;
  overflow-x: auto;
  padding-bottom: 0.35rem;
  scroll-snap-type: x proximity;
}

.rotta-board-column {
  display: flex;
  min-width: 0;
  min-height: 12rem;
  flex-direction: column;
  @apply bg-n-solid-2 border border-n-weak;
  border-radius: 1rem;
  scroll-snap-align: start;
}

.rotta-board-column--ready {
  @apply border-n-teal-7;
}

.rotta-board-column--attention {
  @apply border-n-ruby-7;
}

.rotta-board-column__header {
  padding: 0.65rem 0.7rem 0.55rem;
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
  gap: 0.45rem;
  padding: 0.45rem;
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
  gap: 0.55rem;
  padding: 0.65rem;
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

.rotta-board-card__topline {
  align-items: flex-start;
  flex-wrap: wrap;
}

.rotta-client--board {
  min-width: min(100%, 8rem);
  flex: 1 1 8rem;
}

.rotta-board-card__topline > .rotta-status {
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
  flex: 0 1 auto;
  text-overflow: ellipsis;
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
  min-width: 0;
  @apply text-n-slate-11;
  font-size: 0.67rem;
}

.rotta-board-card__compact-schedule {
  display: inline-flex;
  align-items: center;
  min-width: 0;
  flex: 1;
  gap: 0.25rem;
}

.rotta-board-card__compact-schedule > span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rotta-board-card__compact-status {
  min-width: 0;
  max-width: 48%;
  overflow: hidden;
  flex: 0 1 auto;
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

.rotta-board-card__schedule-main small.rotta-board-card__countdown {
  @apply text-n-blue-11;
  font-weight: 600;
}

.rotta-board-card__schedule-main small.rotta-board-card__countdown--ready {
  @apply text-n-teal-11;
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

.rotta-follow-up-feedback {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  align-items: start;
  gap: 0.45rem;
  width: 100%;
  padding: 0.5rem 0.6rem;
  border: 1px solid currentColor;
  border-radius: 0.65rem;
  font-size: 0.7rem;
  line-height: 1.35;
}

.rotta-follow-up-feedback__icon {
  width: 1rem;
  height: 1rem;
  margin-top: 0.05rem;
  flex: 0 0 auto;
}

.rotta-follow-up-feedback > div {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 0.12rem;
}

.rotta-follow-up-feedback strong,
.rotta-follow-up-feedback span {
  overflow-wrap: anywhere;
}

.rotta-follow-up-feedback strong {
  color: inherit;
  font-weight: 600;
}

.rotta-follow-up-feedback span {
  color: color-mix(in srgb, currentColor 88%, transparent);
}

.rotta-follow-up-feedback--error {
  @apply text-n-ruby-11 bg-n-ruby-2 border-n-ruby-6;
}

.rotta-follow-up-feedback--waiting {
  @apply text-n-amber-11 bg-n-amber-2 border-n-amber-6;
}

.rotta-follow-up-feedback--table {
  min-width: 14rem;
  max-width: 22rem;
  margin-top: 0.4rem;
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
  .rotta-summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .rotta-failure-row {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto;
  }

  .rotta-failure-row__reason {
    grid-column: 1 / -1;
  }

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

  .rotta-failures__header {
    align-items: stretch;
    flex-direction: column;
  }

  .rotta-failure-row {
    grid-template-columns: minmax(0, 1fr);
    align-items: stretch;
    padding: 0.85rem;
  }

  .rotta-failure-row__reason {
    grid-column: auto;
  }

  .rotta-failure-row > :deep(button) {
    width: 100%;
    min-height: 2.75rem;
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

  .rotta-follow-up-feedback {
    padding: 0.6rem;
    font-size: 0.75rem;
  }

  .rotta-follow-up-feedback--table {
    min-width: 0;
    max-width: none;
  }

  .rotta-view-tabs {
    grid-template-columns: repeat(3, minmax(0, 1fr));
    overflow-x: visible;
  }

  .rotta-view-tabs button {
    width: 100%;
    min-width: 0;
    white-space: normal;
    line-height: 1.2;
  }
}

/* The kanban is the single operational surface; the legacy table markup is
   kept below temporarily so the migration remains easy to review. */
.rotta-queue__desktop,
.rotta-queue__mobile {
  display: none !important;
}

.rotta-queue__desktop--visible {
  display: block !important;
}

@media (max-width: 1023px) {
  .rotta-queue__desktop--visible {
    display: none !important;
  }

  .rotta-queue__mobile {
    display: grid !important;
    gap: 0.75rem;
  }
}

@media (max-width: 1023px) {
  .rotta-board:not(.rotta-board--trails) {
    grid-template-columns: repeat(2, minmax(16rem, 1fr));
  }

  .rotta-board--trails {
    grid-template-columns: none;
    grid-auto-columns: minmax(16rem, 18rem);
  }
}

@media (max-width: 640px) {
  .rotta-board {
    grid-template-columns: minmax(0, 1fr);
  }

  .rotta-board--trails {
    grid-template-columns: none;
    grid-auto-columns: min(21rem, calc(100vw - 3.75rem));
    scroll-padding-inline: 0.1rem;
  }

  .rotta-view-tabs {
    margin-inline: -0.25rem;
    padding-inline: 0.25rem;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    overflow-x: visible;
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

@media (max-width: 320px) {
  .rotta-view-tabs button {
    flex-direction: column;
    gap: 0.2rem;
    padding: 0.5rem 0.35rem;
    font-size: 0.78rem;
  }

  .rotta-view-tabs button span {
    min-width: 1.25rem;
    padding-inline: 0.3rem;
  }
}
</style>
