import { describe, expect, it } from 'vitest';
import {
  canRemoveFollowUpLabel,
  followUpActionLabel,
  isExecutableFollowUpJob,
  removeFollowUpJob,
  requiresFollowUpHours,
} from './globalAiFollowUp';

describe('global AI follow-up actions', () => {
  it('exposes the four supported operations with readable labels', () => {
    expect(
      ['dispatch_now', 'advance', 'delay', 'cancel', 'remove_label'].map(
        followUpActionLabel
      )
    ).toEqual([
      'Disparar agora',
      'Adiantar',
      'Atrasar',
      'Cancelar',
      'Remover etiqueta',
    ]);
  });

  it('requires hours only for advance and delay', () => {
    expect(requiresFollowUpHours('advance')).toBe(true);
    expect(requiresFollowUpHours('delay')).toBe(true);
    expect(requiresFollowUpHours('dispatch_now')).toBe(false);
    expect(requiresFollowUpHours('cancel')).toBe(false);
  });

  it('does not expose provisional jobs as executable actions', () => {
    expect(isExecutableFollowUpJob({ job_id: 'job-1' })).toBe(true);
    expect(isExecutableFollowUpJob({ job_id: 'pending:2165:kelvin' })).toBe(
      false
    );
    expect(
      removeFollowUpJob([{ job_id: 'job-1' }, { job_id: 'job-2' }], 'job-1')
    ).toEqual([{ job_id: 'job-2' }]);
  });

  it('allows removing a linked label while its remote job is syncing', () => {
    expect(
      canRemoveFollowUpLabel({
        conversation_id: '2165',
        job_id: 'pending:2165:primeiro-contato',
        current_label: 'Primeiro contato',
      })
    ).toBe(true);
    expect(canRemoveFollowUpLabel({ job_id: 'pending:2165:x' })).toBe(false);
  });
});
