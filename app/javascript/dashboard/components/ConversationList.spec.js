import { shallowMount } from '@vue/test-utils';
import ConversationList from './ConversationList.vue';

vi.mock('dashboard/composables/chatlist/useChatListKeyboardEvents', () => ({
  useChatListKeyboardEvents: vi.fn(),
}));

vi.mock('@vueuse/core', () => ({
  useBreakpoints: () => ({
    greaterOrEqual: () => ({ value: true }),
  }),
}));

const mountConversationList = props =>
  shallowMount(ConversationList, {
    props: {
      conversationList: [],
      ...props,
    },
    global: {
      stubs: {
        Virtualizer: { template: '<div><slot :item="{}" /></div>' },
        ConversationItem: true,
        Spinner: true,
        IntersectionObserver: true,
      },
    },
  });

describe('ConversationList', () => {
  it('does not request another page while the initial list is displayed', () => {
    const wrapper = mountConversationList();

    expect(
      wrapper.findComponent({ name: 'IntersectionObserver' }).exists()
    ).toBe(false);
  });

  it('enables pagination after a trusted user scroll', async () => {
    const wrapper = mountConversationList();

    wrapper.vm.onConversationListScroll({ isTrusted: true });
    await wrapper.vm.$nextTick();

    expect(
      wrapper.findComponent({ name: 'IntersectionObserver' }).exists()
    ).toBe(true);
  });

  it('keeps the pagination sentinel hidden while the list is loading', () => {
    const wrapper = mountConversationList({ isLoading: true });

    expect(
      wrapper.findComponent({ name: 'IntersectionObserver' }).exists()
    ).toBe(false);
  });
});
