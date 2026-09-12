import { shallowMount } from '@vue/test-utils';
import ChatListHeader from './ChatListHeader.vue';

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountScopedRoute: route => route }),
}));

const mountHeader = () =>
  shallowMount(ChatListHeader, {
    props: {
      pageTitle: 'Conversas',
      hasAppliedFilters: false,
      hasActiveFolders: false,
      activeStatus: 'all',
      isOnExpandedLayout: false,
      conversationStats: { allCount: 0 },
      isListLoading: false,
      showRottaShortcuts: true,
    },
    global: {
      mocks: { $t: key => key },
      directives: { tooltip: () => {} },
      stubs: {
        ComposeConversation: {
          template: '<div><slot name="trigger" :is-open="false" /></div>',
        },
        ConversationBasicFilter: true,
        FilterSelect: true,
        NextButton: {
          props: ['label'],
          template: '<button>{{ label }}</button>',
        },
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
  });

describe('ChatListHeader', () => {
  it('keeps the read-all action without duplicating the all or archived shortcuts', () => {
    const wrapper = mountHeader();

    expect(wrapper.text()).toContain('Ler tudo');
    expect(wrapper.text()).not.toContain(
      'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.all.TEXT'
    );
    expect(wrapper.text()).not.toContain('Arquivados');
  });
});
