import {
  CONFIGURED_DELAY_HOURS,
  countdownPartsFor,
  dispatchWindowFor,
  effectiveDispatchAt,
  isHistoricalJob,
  isStaleHistoricalJob,
  deduplicateFollowUpJobs,
  isWithinDispatchWindow,
  kanbanBucketFor,
  delayHoursFor,
  FOLLOW_UP_STAGE_ORDER,
  CONTACT_TRAIL_STAGES,
  BUDGET_TRAIL_STAGES,
  followUpTrailForJob,
  followUpTrailForStage,
  activeFollowUpStageCount,
  isArchivedStage,
  compactDispatchText,
  orderedTrailStages,
  orderedFollowUpStages,
} from '../followUpHelpers';

const WINDOW = {
  start: '06:00',
  end: '23:00',
  timezone: 'America/Sao_Paulo',
};

describe('follow-up helpers', () => {
  it('counts only stages with current active follow-up jobs', () => {
    expect(activeFollowUpStageCount([])).toBe(0);
    expect(
      activeFollowUpStageCount([
        { status: 'pending', current_label: 'primeiro-contato' },
        { status: 'pending', current_label: 'primeiro-contato' },
        { status: 'pending', current_label: 'segundo-contato' },
        { status: 'sent_history', current_label: 'terceiro-contato' },
      ])
    ).toBe(2);
  });

  it('keeps historical jobs out of the active kanban', () => {
    expect(isHistoricalJob({ status: 'sent_history' })).toBe(true);
    expect(kanbanBucketFor({ status: 'history_only' })).toBe('history');
  });

  it('does not expose historical jobs whose current Chatwoot label is gone', () => {
    expect(
      isStaleHistoricalJob({
        status: 'sent_history',
        current_label: 'primeiro-contato',
        active_labels: [],
      })
    ).toBe(true);
    expect(
      isStaleHistoricalJob({
        status: 'sent_history',
        current_label: 'primeiro-contato',
        active_labels: ['primeiro-contato'],
      })
    ).toBe(false);
    expect(
      isStaleHistoricalJob({
        status: 'pending',
        current_label: 'primeiro-contato',
        active_labels: [],
      })
    ).toBe(false);
    expect(
      isStaleHistoricalJob({
        status: 'sent_history',
        current_label: 'primeiro-contato',
      })
    ).toBe(true);
  });

  it('counts the same conversation and stage only once', () => {
    expect(
      deduplicateFollowUpJobs([
        { job_id: 'one', conversation_id: 42, current_label: 'kelvin' },
        { job_id: 'two', conversation_id: 42, current_label: 'kelvin' },
        {
          job_id: 'three',
          conversation_id: 42,
          current_label: 'primeiro-contato',
        },
      ])
    ).toHaveLength(2);
  });

  it('keeps different historical events when they belong to different stages', () => {
    const jobs = [
      {
        conversation_id: 42,
        current_label: 'Primeiro contato',
        status: 'sent_history',
        active_labels: ['Primeiro contato'],
      },
      {
        conversation_id: 42,
        current_label: 'Segundo contato',
        status: 'sent_history',
        active_labels: ['Segundo contato'],
      },
    ];

    expect(deduplicateFollowUpJobs(jobs)).toEqual(jobs);
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

  it('keeps the minimized card dispatch time short and explicit', () => {
    expect(
      compactDispatchText(
        { scheduled_at: '2026-09-09T23:00:00Z' },
        Date.parse('2026-09-09T12:00:00Z'),
        WINDOW
      )
    ).toBe('Disparo 09/09 20:00');

    expect(
      compactDispatchText(
        {
          delivery_evidence: {
            message_id: 'message-1',
            created_at: '2026-09-09T23:00:00Z',
          },
        },
        Date.parse('2026-09-09T12:00:00Z'),
        WINDOW
      )
    ).toBe('Enviado 09/09 20:00');
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
    expect(FOLLOW_UP_STAGE_ORDER[0]).toBe('primeiro-contato');
  });

  it('orders every visible contact and budget stage without treating archive as a stage', () => {
    expect(
      orderedTrailStages(
        [
          'arquivado',
          'ultimo-contato',
          'terceiro-contato',
          'segundo-contato',
          'primeiro-contato',
        ],
        'contact'
      )
    ).toEqual(CONTACT_TRAIL_STAGES);
    expect(
      orderedTrailStages(
        [
          'orcamento-15-dias',
          'orcamento-feito',
          'arquivado',
          'orcamento-tentativa-3',
          'orcamento-tentativa-2',
          'orcamento-10-dias',
          'orcamento-tentativa-4',
          'orcamento-5-dias',
        ],
        'budget'
      )
    ).toEqual(BUDGET_TRAIL_STAGES);
  });

  it('routes jobs to the trail represented by their current or historical labels', () => {
    expect(followUpTrailForStage('primeiro-contato')).toBe('contact');
    expect(followUpTrailForStage('orcamento-tentativa-3')).toBe('budget');
    expect(
      followUpTrailForJob({
        current_label: 'primeiro-contato',
        history: [{ label: 'orcamento-feito' }],
      })
    ).toBe('budget');
    expect(followUpTrailForJob({ current_label: 'segundo-contato' })).toBe(
      'contact'
    );
  });

  it('keeps archived jobs out of both the board and its stage counts', () => {
    expect(isArchivedStage('arquivado')).toBe(true);
    expect(isArchivedStage('clientes-fechados')).toBe(true);
    expect(followUpTrailForJob({ current_label: 'arquivado' })).toBe(null);
    expect(
      orderedTrailStages(['primeiro-contato', 'arquivado'], 'contact')
    ).toEqual(['primeiro-contato']);
    expect(
      orderedTrailStages(['orcamento-feito', 'clientes-fechados'], 'budget')
    ).toEqual(['orcamento-feito']);
  });
});
