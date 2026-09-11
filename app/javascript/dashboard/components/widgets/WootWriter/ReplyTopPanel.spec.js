import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import ReplyTopPanel from './ReplyTopPanel.vue';
import { REPLY_EDITOR_MODES } from './constants';

vi.mock('dashboard/composables/useCaptain', () => ({
  useCaptain: () => ({ captainTasksEnabled: true }),
}));

vi.mock('./CopilotMenuBar.vue', () => ({
  default: { template: '<div />' },
}));

describe('ReplyTopPanel', () => {
  it('forwards editor mode clicks to the parent', async () => {
    const wrapper = mount(ReplyTopPanel, {
      props: {
        mode: REPLY_EDITOR_MODES.REPLY,
        conversationAiActive: true,
      },
      global: {
        mocks: { $t: key => key },
        stubs: { CopilotMenuBar: true },
      },
    });

    await wrapper.get('[data-private-note-mode]').trigger('click');

    expect(wrapper.emitted('setReplyMode')).toEqual([
      [REPLY_EDITOR_MODES.NOTE],
    ]);
  });
});
