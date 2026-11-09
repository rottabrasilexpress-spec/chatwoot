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
          subscribe: vi.fn(),
          unsubscribe: vi.fn(),
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
  it('refreshes on return to the tab and removes the visibility listener on unmount', async () => {
    const hidden = vi.spyOn(document, 'hidden', 'get').mockReturnValue(true);
    const wrapper = mountStatus({ state: 'unknown' });
    const dispatch = vi.spyOn(wrapper.vm.$store, 'dispatch');
    hidden.mockReturnValue(false);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(dispatch).toHaveBeenCalledWith('conversationAiStatus/ensure', 42);
    await wrapper.setProps({ conversationId: 43 });
    expect(dispatch).toHaveBeenCalledWith(
      'conversationAiStatus/unsubscribe',
      42
    );
    expect(dispatch).toHaveBeenCalledWith('conversationAiStatus/subscribe', 43);
    wrapper.unmount();
    expect(dispatch).toHaveBeenCalledWith(
      'conversationAiStatus/unsubscribe',
      43
    );
    dispatch.mockClear();
    document.dispatchEvent(new Event('visibilitychange'));
    expect(dispatch).not.toHaveBeenCalled();
    hidden.mockRestore();
    dispatch.mockRestore();
  });
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
