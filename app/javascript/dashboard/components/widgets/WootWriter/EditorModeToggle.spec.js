import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import EditorModeToggle from './EditorModeToggle.vue';
import { REPLY_EDITOR_MODES } from './constants';

describe('EditorModeToggle', () => {
  it('keeps reply, private note, and conversation AI controls independent', async () => {
    const wrapper = mount(EditorModeToggle, {
      props: {
        mode: REPLY_EDITOR_MODES.REPLY,
        showConversationAi: true,
      },
    });

    const buttons = wrapper.findAll('button');
    expect(buttons).toHaveLength(3);

    await wrapper.get('[data-reply-mode]').trigger('click');
    expect(wrapper.emitted('setReplyMode')).toEqual([
      [REPLY_EDITOR_MODES.REPLY],
    ]);

    await wrapper.get('[data-private-note-mode]').trigger('click');
    expect(wrapper.emitted('setReplyMode')).toEqual([
      [REPLY_EDITOR_MODES.REPLY],
      [REPLY_EDITOR_MODES.NOTE],
    ]);

    await wrapper.get('[data-conversation-ai-toggle]').trigger('click');
    expect(wrapper.emitted('openConversationAi')).toHaveLength(1);
    expect(wrapper.emitted('setReplyMode')).toHaveLength(2);
  });

  it('exposes an explicit visual active state for each mode', () => {
    const noteWrapper = mount(EditorModeToggle, {
      props: {
        mode: REPLY_EDITOR_MODES.NOTE,
        showConversationAi: true,
      },
    });

    expect(noteWrapper.get('[data-reply-mode]').attributes('data-active')).toBe(
      'false'
    );
    expect(
      noteWrapper.get('[data-private-note-mode]').attributes('data-active')
    ).toBe('true');
    expect(
      noteWrapper.get('[data-conversation-ai-toggle]').attributes('data-active')
    ).toBe('false');

    const aiWrapper = mount(EditorModeToggle, {
      props: {
        showConversationAi: true,
        conversationAiActive: true,
      },
    });

    expect(
      aiWrapper.get('[data-conversation-ai-toggle]').attributes('data-active')
    ).toBe('true');
  });
});
