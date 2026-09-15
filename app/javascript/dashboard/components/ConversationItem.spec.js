import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ConversationItem from './ConversationItem.vue';
import ConversationCard from './widgets/conversation/ConversationCard.vue';
import MenuItem from './widgets/conversation/contextMenu/menuItem.vue';

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/helper/URLHelper', () => ({
  frontendURL: path => path,
  conversationUrl: () => '/accounts/1/conversations/2441',
}));

vi.mock('dashboard/helper/conversationHelper', () => ({
  hasUnreadIncomingMessage: () => false,
}));

const ConversationCardStub = {
  emits: ['contextmenu'],
  template: '<div @contextmenu="$emit(\'contextmenu\', $event)"></div>',
};

const mountConversationItem = () => {
  const store = createStore({
    getters: {
      getSelectedChat: () => ({ id: null }),
      getCurrentAccountId: () => 1,
      getCurrentUser: () => ({ id: 1 }),
      getCurrentRole: () => 'agent',
    },
    modules: {
      inboxes: {
        namespaced: true,
        getters: {
          getInboxes: () => [],
          getSelectedInbox: () => null,
          getInbox: () => () => ({ id: 1 }),
        },
      },
      contacts: {
        namespaced: true,
        getters: { getContact: () => () => ({}) },
      },
      labels: {
        namespaced: true,
        getters: {
          getLabels: () => [
            { id: 1, title: 'emitir-contrato', color: '#7c3aed' },
          ],
        },
      },
    },
  });

  return mount(ConversationItem, {
    props: {
      source: {
        id: 2441,
        labels: [],
        messages: [],
        meta: {},
        inbox_id: 1,
        priority: '0',
        custom_attributes: {},
      },
    },
    global: {
      plugins: [store],
      provide: {
        selectConversation: vi.fn(),
        deSelectConversation: vi.fn(),
        assignLabels: vi.fn(),
        removeLabels: vi.fn(),
        updateConversationStatus: vi.fn(),
        toggleContextMenu: vi.fn(),
        markAsUnread: vi.fn(),
        markAsRead: vi.fn(),
        assignPriority: vi.fn(),
        isConversationSelected: () => false,
        deleteConversation: vi.fn(),
        togglePinned: vi.fn(),
      },
      stubs: {
        ConversationCard: ConversationCardStub,
        ConversationCardExpanded: true,
        ContextMenu: { template: '<div><slot /></div>' },
        ConfirmationModal: true,
        'fluent-icon': true,
      },
      mocks: { $t: key => key },
    },
  });
};

describe('ConversationItem contract shortcut', () => {
  it('renders the sidebar display name instead of the technical label slug', async () => {
    const wrapper = mountConversationItem();

    await wrapper.findComponent(ConversationCard).trigger('contextmenu', {
      pageX: 100,
      pageY: 100,
    });

    const action = wrapper
      .findAllComponents(MenuItem)
      .find(item => item.props('option').key === 'issue-contract');

    expect(action.text()).toBe('Emitir Contrato');
  });
});
