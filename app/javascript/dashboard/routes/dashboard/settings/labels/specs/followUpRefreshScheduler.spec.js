import { createFollowUpRefreshScheduler } from '../followUpRefreshScheduler';

describe('follow-up refresh scheduler', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('coalesces a realtime event burst into one queue refresh', () => {
    const refresh = vi.fn();
    const scheduler = createFollowUpRefreshScheduler({ refresh });

    scheduler.schedule();
    vi.advanceTimersByTime(100);
    scheduler.schedule();
    vi.advanceTimersByTime(100);
    scheduler.schedule();
    vi.advanceTimersByTime(5000);

    expect(refresh).toHaveBeenCalledTimes(1);
  });
});
