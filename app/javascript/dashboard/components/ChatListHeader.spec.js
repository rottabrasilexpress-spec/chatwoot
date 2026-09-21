import { defineComponent, h } from 'vue';
import { shallowMount } from '@vue/test-utils';
import ChatListHeader from './ChatListHeader.vue';

const openFocusDialog = vi.fn();
const closeFocusDialog = vi.fn();

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: 1 } }),
  useRouter: () => ({
    resolve: () => ({ href: '/app/accounts/1/conversations-focus' }),
  }),
}));

const DialogStub = defineComponent({
  emits: ['confirm'],
  setup(_, { emit, expose }) {
    expose({ open: openFocusDialog, close: closeFocusDialog });
    return () =>
      h('button', { class: 'confirm-focus', onClick: () => emit('confirm') });
  },
});

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
        Dialog: DialogStub,
        NextButton: {
          props: ['label'],
          template: '<button>{{ label }}</button>',
        },
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
  });

describe('ChatListHeader', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('keeps the read-all action without duplicating the all or archived shortcuts', () => {
    const wrapper = mountHeader();

    expect(wrapper.text()).toContain('Ler tudo');
    expect(wrapper.text()).not.toContain(
      'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.all.TEXT'
    );
    expect(wrapper.text()).not.toContain('Arquivados');
  });

  it('anchors the search icon on the right side of the search field', () => {
    const wrapper = mountHeader();

    expect(wrapper.find('.i-lucide-search').classes()).toContain(
      'ltr:right-2.5'
    );
  });

  it('opens the focused-mode confirmation from its toolbar button', async () => {
    const wrapper = mountHeader();

    await wrapper
      .find('[aria-label="Abrir modo focado de conversas"]')
      .trigger('click');

    expect(openFocusDialog).toHaveBeenCalledOnce();
  });

  it('opens focused mode in an independent page without replacing Chatwoot', async () => {
    const openWindow = vi.spyOn(window, 'open').mockImplementation(() => null);
    const wrapper = mountHeader();

    await wrapper.find('.confirm-focus').trigger('click');

    expect(closeFocusDialog).toHaveBeenCalledOnce();
    expect(openWindow).toHaveBeenCalledWith(
      '/app/accounts/1/conversations-focus',
      '_blank',
      'noopener,noreferrer'
    );
  });
});
