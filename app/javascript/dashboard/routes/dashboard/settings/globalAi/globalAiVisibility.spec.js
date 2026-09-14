import { describe, expect, it } from 'vitest';
import {
  canViewGlobalAi,
  DEFAULT_GLOBAL_AI_OWNER_EMAIL,
} from './globalAiVisibility';

describe('canViewGlobalAi', () => {
  it('lets the default owner see the assistant before the owner setting is persisted', () => {
    expect(
      canViewGlobalAi({
        settings: {},
        currentUser: { email: DEFAULT_GLOBAL_AI_OWNER_EMAIL, id: 7 },
      })
    ).toBe(true);
  });

  it('keeps another agent hidden until the owner shares it', () => {
    expect(
      canViewGlobalAi({
        settings: {
          rotta_global_ai_owner_id: 7,
          rotta_global_ai_shared_user_ids: [],
        },
        currentUser: { email: 'caio@example.com', id: 8 },
      })
    ).toBe(false);
  });

  it('shows the shared agent and never treats sharing as cross-account access', () => {
    expect(
      canViewGlobalAi({
        settings: {
          rotta_global_ai_owner_id: 7,
          rotta_global_ai_shared_user_ids: [8],
        },
        currentUser: { email: 'caio@example.com', id: 8 },
      })
    ).toBe(true);
  });
});
