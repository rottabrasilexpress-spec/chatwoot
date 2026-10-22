import { shallowMount } from '@vue/test-utils';
import Copilot from './Copilot.vue';

vi.mock('dashboard/composables', () => ({ useTrack: vi.fn() }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ updateUISettings: vi.fn() }),
}));

describe('conversation AI response state', () => {
  it('shows a recoverable error instead of thinking forever after a response timeout', () => {
    const wrapper = shallowMount(Copilot, {
      props: {
        conversationInboxType: 'Channel::Api',
        conversationAiMode: true,
        messages: [
          { id: 90, message_type: 'user', message: { content: 'Resumo' } },
        ],
        responsePending: false,
        responseError: 'A resposta demorou mais que o esperado.',
      },
    });

    expect(wrapper.findComponent({ name: 'CopilotLoader' }).exists()).toBe(
      false
    );
    expect(wrapper.text()).toContain('A resposta demorou mais que o esperado.');
    const retry = wrapper.find('[data-conversation-ai-refresh]');
    expect(retry.exists()).toBe(true);
    retry.trigger('click');
    expect(wrapper.emitted('refreshResponse')).toHaveLength(1);
  });
});
