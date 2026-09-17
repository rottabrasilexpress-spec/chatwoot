export const createFollowUpRefreshScheduler = ({
  refresh,
  debounceMs = 400,
  timer = window,
}) => {
  let realtimeTimer;

  const schedule = () => {
    timer.clearTimeout(realtimeTimer);
    realtimeTimer = timer.setTimeout(() => {
      realtimeTimer = undefined;
      refresh();
    }, debounceMs);
  };

  const dispose = () => {
    timer.clearTimeout(realtimeTimer);
  };

  return { schedule, dispose };
};
