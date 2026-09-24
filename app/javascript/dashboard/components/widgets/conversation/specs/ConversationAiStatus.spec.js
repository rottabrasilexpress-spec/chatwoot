import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ConversationAiStatus from '../ConversationAiStatus.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => (key.endsWith('UNKNOWN_SHORT') ? '?' : key.split('.').at(-1)),
  }),
}));

const mountStatus = status => {
  const store = createStore({
    modules: {
      conversationAiStatus: {
        namespaced: true,
        getters: {
          getStatus: () => () => status,
        },
        actions: {
          ensure: vi.fn(),
        },
      },
    },
  });

  return mount(ConversationAiStatus, {
    props: { conversationId: 42 },
    global: { plugins: [store] },
  });
};

describe('ConversationAiStatus', () => {
  it('shows a red OFF badge when the AI is blocked', () => {
    const wrapper = mountStatus({ state: 'blocked' });

    expect(wrapper.get('[data-ai-status="blocked"]').text()).toContain('OFF');
    expect(wrapper.get('[data-ai-status="blocked"]').classes()).toContain(
      'text-n-ruby-11'
    );
    wrapper.unmount();
  });

  it('shows a green ON badge when the AI is active', () => {
    const wrapper = mountStatus({ state: 'active' });

    expect(wrapper.get('[data-ai-status="active"]').text()).toContain('ON');
    expect(wrapper.get('[data-ai-status="active"]').classes()).toContain(
      'text-n-teal-11'
    );
    wrapper.unmount();
  });

  it('never presents an unavailable status as active', () => {
    const wrapper = mountStatus({ state: 'unknown' });

    expect(wrapper.find('[data-ai-status="active"]').exists()).toBe(false);
    expect(wrapper.find('[data-ai-status="blocked"]').exists()).toBe(false);
    expect(wrapper.get('[data-ai-status="unknown"]').text()).toContain('?');
    wrapper.unmount();
  });
});
