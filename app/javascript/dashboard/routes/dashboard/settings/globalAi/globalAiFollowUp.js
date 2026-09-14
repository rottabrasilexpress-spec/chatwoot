export const FOLLOW_UP_OPERATION_LABELS = {
  dispatch_now: 'Disparar agora',
  advance: 'Adiantar',
  delay: 'Atrasar',
  cancel: 'Cancelar',
  remove_label: 'Remover etiqueta',
};

export const FOLLOW_UP_OPERATIONS_REQUIRING_HOURS = new Set([
  'advance',
  'delay',
]);

export const followUpActionLabel = operation =>
  FOLLOW_UP_OPERATION_LABELS[operation] || operation;

export const requiresFollowUpHours = operation =>
  FOLLOW_UP_OPERATIONS_REQUIRING_HOURS.has(operation);

export const isExecutableFollowUpJob = job => {
  const jobId = String(job?.job_id || '').trim();
  return Boolean(jobId) && !jobId.startsWith('pending:');
};

export const canRemoveFollowUpLabel = job =>
  Boolean(
    job?.conversation_id &&
      String(job?.current_label || job?.source_label || '').trim()
  );

export const removeFollowUpJob = (jobs, jobId) =>
  (Array.isArray(jobs) ? jobs : []).filter(
    job => String(job?.job_id || '') !== String(jobId || '')
  );
