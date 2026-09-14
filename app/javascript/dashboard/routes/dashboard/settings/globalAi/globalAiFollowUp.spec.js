import { describe, expect, it } from 'vitest';
import {
  followUpActionLabel,
  isExecutableFollowUpJob,
  removeFollowUpJob,
  requiresFollowUpHours,
} from './globalAiFollowUp';

describe('global AI follow-up actions', () => {
  it('exposes the four supported operations with readable labels', () => {
    expect(
      ['dispatch_now', 'advance', 'delay', 'cancel'].map(followUpActionLabel)
    ).toEqual(['Disparar agora', 'Adiantar', 'Atrasar', 'Cancelar']);
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
});
