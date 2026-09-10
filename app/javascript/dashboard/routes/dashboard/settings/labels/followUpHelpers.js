const TIMEZONE = 'America/Sao_Paulo';

export const DEFAULT_DISPATCH_WINDOW = {
  start: '06:00',
  end: '23:00',
  timezone: TIMEZONE,
};

// This is the published Rotta/n8n schedule. API metadata wins when the
// workflow returns it; these values keep the board useful while the legacy
// admin endpoint is upgraded to expose its configuration.
export const CONFIGURED_DELAY_HOURS = {
  'contato-instantaneo': 0,
  'primeiro-contato': 36,
  'segundo-contato': 55,
  'terceiro-contato': 72,
  'ultimo-contato': 96,
  'orcamento-instantaneo': 0,
  'orcamento-feito': 36,
  'orcamento-tentativa-2': 55,
  'orcamento-tentativa-3': 72,
  'orcamento-tentativa-4': 96,
  'orcamento-5-dias': 120,
  'orcamento-10-dias': 240,
  'orcamento-15-dias': 360,
};

// These are the operational slugs used by the existing n8n workflow. The
// legacy "ultimo-contato" slug is intentionally retained as the API value;
// the UI presents it as the fourth contact attempt.
export const CONTACT_TRAIL_STAGES = [
  'primeiro-contato',
  'segundo-contato',
  'terceiro-contato',
  'ultimo-contato',
];

export const BUDGET_TRAIL_STAGES = [
  'orcamento-feito',
  'orcamento-tentativa-2',
  'orcamento-tentativa-3',
  'orcamento-tentativa-4',
  'orcamento-5-dias',
  'orcamento-10-dias',
  'orcamento-15-dias',
];

export const FOLLOW_UP_STAGE_TITLES = Object.freeze({
  'primeiro-contato': 'Primeiro contato',
  'segundo-contato': 'Segundo contato',
  'terceiro-contato': 'Terceiro contato',
  'ultimo-contato': 'Quarto contato',
  'orcamento-feito': 'Orçamento feito',
  'orcamento-tentativa-2': 'Segundo orçamento',
  'orcamento-tentativa-3': 'Terceiro orçamento',
  'orcamento-tentativa-4': 'Quarto orçamento',
  'orcamento-5-dias': 'Orçamento 5 dias',
  'orcamento-10-dias': 'Orçamento 10 dias',
  'orcamento-15-dias': 'Orçamento 15 dias',
});

export const ARCHIVED_FOLLOW_UP_STAGES = ['arquivado'];

export const FOLLOW_UP_TRAILS = Object.freeze({
  contact: CONTACT_TRAIL_STAGES,
  budget: BUDGET_TRAIL_STAGES,
});

const LEGACY_STAGE_ALIASES = Object.freeze({
  'contato-instantaneo': 'primeiro-contato',
  'orcamento-instantaneo': 'orcamento-feito',
  'clientes-fechados': 'arquivado',
  'quarto-contato': 'ultimo-contato',
});

const normaliseStage = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[✅❌🫶💰🤝]/gu, '')
    .trim()
    .replace(/\s+/g, '-');

export const canonicalFollowUpStage = value => {
  const stage = normaliseStage(value);
  return LEGACY_STAGE_ALIASES[stage] || stage;
};

export const isArchivedStage = stage =>
  ARCHIVED_FOLLOW_UP_STAGES.includes(canonicalFollowUpStage(stage));

export const followUpTrailForStage = stage => {
  const canonicalStage = canonicalFollowUpStage(stage);
  if (CONTACT_TRAIL_STAGES.includes(canonicalStage)) return 'contact';
  if (BUDGET_TRAIL_STAGES.includes(canonicalStage)) return 'budget';
  return null;
};

const historyLabelsFor = job =>
  ['history', 'sent_history', 'dispatched_labels', 'follow_up_history'].flatMap(
    key =>
      Array.isArray(job?.[key])
        ? job[key]
            .map(item =>
              typeof item === 'string'
                ? item
                : item?.label || item?.slug || item?.name
            )
            .filter(Boolean)
        : []
  );

export const followUpTrailForJob = job => {
  const currentStage = canonicalFollowUpStage(
    job?.current_label || job?.source_label || ''
  );
  if (isArchivedStage(currentStage)) return null;

  const stages = [
    currentStage,
    job?.source_label,
    job?.next_label,
    ...historyLabelsFor(job),
  ];
  return stages.some(stage => followUpTrailForStage(stage) === 'budget')
    ? 'budget'
    : 'contact';
};

export const FOLLOW_UP_STAGE_ORDER = [
  ...CONTACT_TRAIL_STAGES,
  ...BUDGET_TRAIL_STAGES,
  ...ARCHIVED_FOLLOW_UP_STAGES,
  'contato-instantaneo',
  'orcamento-instantaneo',
  'clientes-fechados',
];

export const orderedTrailStages = (stages, trailKey) => {
  const configuredStages = FOLLOW_UP_TRAILS[trailKey] || [];
  const presentStages = new Set(
    stages.filter(Boolean).map(canonicalFollowUpStage)
  );
  return configuredStages.filter(stage => presentStages.has(stage));
};

export const orderedFollowUpStages = stages => {
  const uniqueStages = [...new Set(stages.filter(Boolean))];
  const knownStages = FOLLOW_UP_STAGE_ORDER.filter(stage =>
    uniqueStages.includes(stage)
  );
  const additionalStages = uniqueStages
    .filter(stage => !FOLLOW_UP_STAGE_ORDER.includes(stage))
    .sort((a, b) => String(a).localeCompare(String(b), 'pt-BR'));
  return [...knownStages, ...additionalStages];
};

const HISTORICAL_STATUSES = new Set(['sent_history', 'history_only']);

export const isHistoricalJob = job => HISTORICAL_STATUSES.has(job?.status);

export const currentStageFor = job =>
  job?.current_label || job?.source_label || '';

// The admin endpoint keeps dispatch history for auditability and also returns
// the labels currently present on the Chatwoot conversation. A historical row
// is stale when its old stage is no longer one of those active labels. Missing
// active_labels is treated as stale: without that confirmation the UI cannot
// safely count the row as a current follow-up.
export const isStaleHistoricalJob = job => {
  if (!isHistoricalJob(job)) return false;
  if (!Array.isArray(job?.active_labels)) return true;

  const currentStage = canonicalFollowUpStage(currentStageFor(job));
  return (
    Boolean(currentStage) &&
    !job.active_labels.some(
      label => canonicalFollowUpStage(label) === currentStage
    )
  );
};

export const deduplicateFollowUpJobs = jobs => {
  // This is intentionally a board-level projection: the admin response and
  // conversation message history remain untouched. The operational board has
  // one row per conversation and stage, while different stages stay visible.
  const seen = new Set();

  return (Array.isArray(jobs) ? jobs : []).filter((job, index) => {
    const conversationId = job?.conversation_id;
    const stage = canonicalFollowUpStage(currentStageFor(job));
    const key =
      conversationId && stage
        ? `${conversationId}:${stage}`
        : `unkeyed:${job?.job_id || job?.id || index}`;

    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

const firstPresent = values =>
  values.find(value => value !== undefined && value !== null && value !== '');

const parseDelayHours = value => {
  if (typeof value === 'number') return value;
  const match = String(value || '').match(
    /(\d+(?:\.\d+)?)\s*(hour|hours|h|day|days|d)?/i
  );
  if (!match) return Number.NaN;
  const amount = Number(match[1]);
  return /day|d/i.test(match[2] || '') ? amount * 24 : amount;
};

export const delayHoursFor = job => {
  const raw = firstPresent([
    job?.delay_hours,
    job?.programmed_delay_hours,
    job?.wait_hours,
    job?.delay,
  ]);
  const parsed = parseDelayHours(raw);
  if (Number.isFinite(parsed) && parsed >= 0) {
    return { hours: parsed, source: 'api' };
  }

  const configured = CONFIGURED_DELAY_HOURS[currentStageFor(job)];
  return Number.isFinite(configured)
    ? { hours: configured, source: 'configured' }
    : { hours: null, source: 'unavailable' };
};

const normaliseTime = value => {
  const match = String(value || '').match(/^(\d{1,2}):(\d{2})(?::\d{2})?$/);
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (hours > 23 || minutes > 59) return null;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
};

const windowFromValue = value => {
  if (!value) return null;
  if (typeof value === 'object') {
    const start = normaliseTime(value.start || value.from || value.open);
    const end = normaliseTime(value.end || value.to || value.close);
    if (start && end) return { start, end };
  }

  const match = String(value).match(
    /(\d{1,2}:\d{2})\s*[–—-]\s*(\d{1,2}:\d{2})/
  );
  if (!match) return null;
  const start = normaliseTime(match[1]);
  const end = normaliseTime(match[2]);
  return start && end ? { start, end } : null;
};

export const dispatchWindowFor = (job, responseMeta = {}) => {
  const raw = firstPresent([
    job?.dispatch_window,
    job?.allowed_dispatch_window,
    job?.window,
    responseMeta.dispatch_window,
    responseMeta.allowed_dispatch_window,
    responseMeta.window,
  ]);
  const parsed = windowFromValue(raw);
  return {
    ...(parsed || DEFAULT_DISPATCH_WINDOW),
    timezone:
      job?.timezone ||
      responseMeta.timezone ||
      DEFAULT_DISPATCH_WINDOW.timezone,
    source: parsed ? 'api' : 'configured',
  };
};

const dateTimeParts = (date, timezone) => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date(date));
  return Object.fromEntries(
    parts
      .filter(({ type }) => type !== 'literal')
      .map(({ type, value }) => [type, Number(value)])
  );
};

const localTimeToDate = ({ year, month, day }, time, timezone) => {
  const [hour, minute] = time.split(':').map(Number);
  const guess = Date.UTC(year, month - 1, day, hour, minute);
  const displayed = dateTimeParts(guess, timezone);
  const displayedAsUtc = Date.UTC(
    displayed.year,
    displayed.month - 1,
    displayed.day,
    displayed.hour,
    displayed.minute
  );
  return new Date(guess - (displayedAsUtc - guess));
};

const addLocalDays = ({ year, month, day }, days) => {
  const date = new Date(Date.UTC(year, month - 1, day + days));
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
  };
};

const minutesFor = time => {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
};

export const isWithinDispatchWindow = (
  date,
  window = DEFAULT_DISPATCH_WINDOW
) => {
  const parts = dateTimeParts(date, window.timezone || TIMEZONE);
  const minutes = parts.hour * 60 + parts.minute;
  return (
    minutes >= minutesFor(window.start) && minutes <= minutesFor(window.end)
  );
};

export const effectiveDispatchAt = (
  scheduledAt,
  now = Date.now(),
  window = DEFAULT_DISPATCH_WINDOW
) => {
  const scheduled = new Date(scheduledAt).getTime();
  if (!Number.isFinite(scheduled)) return null;

  const timezone = window.timezone || TIMEZONE;
  const current = dateTimeParts(now, timezone);
  const currentMinutes = current.hour * 60 + current.minute;
  const startMinutes = minutesFor(window.start);
  const endMinutes = minutesFor(window.end);
  const currentDate = {
    year: current.year,
    month: current.month,
    day: current.day,
  };

  if (scheduled <= now) {
    if (currentMinutes < startMinutes) {
      return localTimeToDate(currentDate, window.start, timezone).getTime();
    }
    if (currentMinutes > endMinutes) {
      return localTimeToDate(
        addLocalDays(currentDate, 1),
        window.start,
        timezone
      ).getTime();
    }
    return now;
  }

  const scheduledParts = dateTimeParts(scheduled, timezone);
  const scheduledMinutes = scheduledParts.hour * 60 + scheduledParts.minute;
  const scheduledDate = {
    year: scheduledParts.year,
    month: scheduledParts.month,
    day: scheduledParts.day,
  };
  if (scheduledMinutes < startMinutes) {
    return localTimeToDate(scheduledDate, window.start, timezone).getTime();
  }
  if (scheduledMinutes > endMinutes) {
    return localTimeToDate(
      addLocalDays(scheduledDate, 1),
      window.start,
      timezone
    ).getTime();
  }
  return scheduled;
};

const compactDateTime = (date, timezone = TIMEZONE) => {
  if (!Number.isFinite(new Date(date).getTime())) return '';

  const parts = dateTimeParts(date, timezone);
  if (!parts.year) return '';

  return [
    `${String(parts.day).padStart(2, '0')}/${String(parts.month).padStart(2, '0')}`,
    `${String(parts.hour).padStart(2, '0')}:${String(parts.minute).padStart(2, '0')}`,
  ].join(' ');
};

export const compactDispatchText = (
  job,
  now = Date.now(),
  responseMeta = {}
) => {
  const timezone =
    job?.timezone || responseMeta.timezone || DEFAULT_DISPATCH_WINDOW.timezone;
  const evidence = job?.delivery_evidence;

  if (evidence?.message_id) {
    const sentAt = evidence.created_at
      ? compactDateTime(evidence.created_at, timezone)
      : '';
    return sentAt ? `Enviado ${sentAt}` : 'Enviado';
  }

  if (job?.pending_enrollment) {
    return job.status === 'sync_failed'
      ? 'Disparo pendente'
      : 'Disparo sincronizando…';
  }

  const target = effectiveDispatchAt(
    job?.scheduled_at,
    now,
    dispatchWindowFor(job, responseMeta)
  );
  if (!Number.isFinite(target)) return 'Disparo sem horário';

  return `Disparo ${compactDateTime(target, timezone)}`;
};

export const countdownPartsFor = (target, now = Date.now()) => {
  const difference = target - now;
  if (!Number.isFinite(target))
    return { ready: false, text: 'Sem horário definido' };
  if (difference <= 0) return { ready: true, text: 'Pronto para disparar' };

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
  return { ready: false, text: `Faltam ${parts.join(' e ')}` };
};

export const kanbanBucketFor = (job, now = Date.now(), responseMeta = {}) => {
  if (isHistoricalJob(job)) return 'history';
  if (job?.pending_enrollment) {
    return job.status === 'sync_failed' ? 'attention' : 'today';
  }
  if (String(job?.status || '').startsWith('failed')) return 'attention';
  const scheduled = new Date(job?.scheduled_at).getTime();
  if (!Number.isFinite(scheduled)) return 'attention';

  const target = effectiveDispatchAt(
    scheduled,
    now,
    dispatchWindowFor(job, responseMeta)
  );
  if (target <= now) return 'ready';

  const today = dateTimeParts(
    now,
    dispatchWindowFor(job, responseMeta).timezone
  );
  const targetDate = dateTimeParts(
    target,
    dispatchWindowFor(job, responseMeta).timezone
  );
  const todayKey = Date.UTC(today.year, today.month - 1, today.day);
  const targetKey = Date.UTC(
    targetDate.year,
    targetDate.month - 1,
    targetDate.day
  );
  const distance = Math.round((targetKey - todayKey) / 86400000);
  if (distance <= 0) return 'today';
  if (distance === 1) return 'tomorrow';
  return 'upcoming';
};
