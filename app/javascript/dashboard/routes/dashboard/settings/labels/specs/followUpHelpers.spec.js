import {
  CONFIGURED_DELAY_HOURS,
  countdownPartsFor,
  dispatchWindowFor,
  effectiveDispatchAt,
  isHistoricalJob,
  isWithinDispatchWindow,
  kanbanBucketFor,
  delayHoursFor,
  FOLLOW_UP_STAGE_ORDER,
  orderedFollowUpStages,
} from '../followUpHelpers';

const WINDOW = {
  start: '06:00',
  end: '23:00',
  timezone: 'America/Sao_Paulo',
};

describe('follow-up helpers', () => {
  it('keeps historical jobs out of the active kanban', () => {
    expect(isHistoricalJob({ status: 'sent_history' })).toBe(true);
    expect(kanbanBucketFor({ status: 'history_only' })).toBe('history');
  });

  it('prefers delay metadata from the API and falls back to the published label schedule', () => {
    expect(delayHoursFor({ source_label: 'primeiro-contato' })).toEqual({
      hours: CONFIGURED_DELAY_HOURS['primeiro-contato'],
      source: 'configured',
    });
    expect(
      delayHoursFor({ source_label: 'primeiro-contato', delay_hours: 18 })
    ).toEqual({ hours: 18, source: 'api' });
    expect(
      delayHoursFor({ source_label: 'primeiro-contato', delay: '1.5 days' })
    ).toEqual({ hours: 36, source: 'api' });
  });

  it('computes an exact countdown from a provided target', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-08T12:00:00Z'));
    expect(countdownPartsFor(Date.parse('2026-09-08T13:31:00Z')).text).toBe(
      'Faltam 1 hora e 31 minutos'
    );
    vi.useRealTimers();
  });

  it('moves a scheduled dispatch to the next allowed window', () => {
    const beforeWindow = Date.parse('2026-09-08T07:00:00Z'); // 04:00 BRT
    const expected = Date.parse('2026-09-08T09:00:00Z'); // 06:00 BRT
    expect(
      effectiveDispatchAt('2026-09-08T07:00:00Z', beforeWindow, WINDOW)
    ).toBe(expected);

    const afterWindow = Date.parse('2026-09-08T03:00:00Z'); // 00:00 BRT
    expect(isWithinDispatchWindow(afterWindow, WINDOW)).toBe(false);
    expect(isWithinDispatchWindow(expected, WINDOW)).toBe(true);
  });

  it('assigns ready, today, upcoming and attention columns deterministically', () => {
    const now = Date.parse('2026-09-08T15:00:00Z'); // 12:00 BRT
    expect(
      kanbanBucketFor(
        { status: 'pending', scheduled_at: '2026-09-08T14:00:00Z' },
        now,
        { timezone: WINDOW.timezone }
      )
    ).toBe('ready');
    expect(
      kanbanBucketFor(
        { status: 'pending', scheduled_at: '2026-09-08T18:00:00Z' },
        now,
        { timezone: WINDOW.timezone }
      )
    ).toBe('today');
    expect(
      kanbanBucketFor(
        { status: 'pending', scheduled_at: '2026-09-09T18:00:00Z' },
        now,
        { timezone: WINDOW.timezone }
      )
    ).toBe('tomorrow');
    expect(
      kanbanBucketFor({ status: 'failed_send' }, now, {
        timezone: WINDOW.timezone,
      })
    ).toBe('attention');
  });

  it('normalises an API dispatch window without discarding its timezone', () => {
    expect(
      dispatchWindowFor(
        { dispatch_window: '07:30–22:15', timezone: 'America/Sao_Paulo' },
        {}
      )
    ).toEqual({
      start: '07:30',
      end: '22:15',
      timezone: 'America/Sao_Paulo',
      source: 'api',
    });
  });

  it('keeps configured stages in operational order and appends unknown labels', () => {
    expect(
      orderedFollowUpStages([
        'orcamento-feito',
        'primeiro-contato',
        'etapa-customizada',
        'arquivado',
      ])
    ).toEqual([
      'primeiro-contato',
      'orcamento-feito',
      'arquivado',
      'etapa-customizada',
    ]);
    expect(FOLLOW_UP_STAGE_ORDER[0]).toBe('contato-instantaneo');
  });
});
