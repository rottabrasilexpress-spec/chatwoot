export const FOLLOW_UP_OPERATION_LABELS = {
  dispatch_now: 'Disparar agora',
  advance: 'Adiantar',
  delay: 'Atrasar',
  cancel: 'Cancelar',
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

export const removeFollowUpJob = (jobs, jobId) =>
  (Array.isArray(jobs) ? jobs : []).filter(
    job => String(job?.job_id || '') !== String(jobId || '')
  );
