import { flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ConversationItem from './ConversationItem.vue';
import ConfirmationModal from 'dashboard/components/widgets/modal/ConfirmationModal.vue';
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

const mountConversationItem = ({
  source,
  labels = [],
  routeLabel = '',
} = {}) => {
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
            { id: 2, title: 'FINALIZADOS', color: '#7c3aed' },
          ],
        },
      },
    },
  });
  const dispatch = vi.spyOn(store, 'dispatch').mockResolvedValue(undefined);
  const dependencies = {
    selectConversation: vi.fn(),
    deSelectConversation: vi.fn(),
    assignLabels: vi.fn().mockResolvedValue(true),
    removeLabels: vi.fn().mockResolvedValue(true),
    updateConversationStatus: vi.fn(),
    toggleContextMenu: vi.fn(),
    markAsUnread: vi.fn(),
    markAsRead: vi.fn(),
    assignPriority: vi.fn(),
    isConversationSelected: () => false,
    deleteConversation: vi.fn(),
    togglePinned: vi.fn(),
  };

  const wrapper = mount(ConversationItem, {
    props: {
      label: routeLabel,
      source: {
        id: 2441,
        labels,
        messages: [],
        meta: {},
        inbox_id: 1,
        priority: '0',
        custom_attributes: {},
        ...source,
      },
    },
    global: {
      plugins: [store],
      provide: dependencies,
      stubs: {
        ConversationCard: ConversationCardStub,
        ConversationCardExpanded: true,
        TeleportWithDirection: { template: '<div><slot /></div>' },
        ContextMenu: { template: '<div><slot /></div>' },
        Modal: {
          props: ['show'],
          template: '<div v-if="show" role="dialog"><slot /></div>',
        },
        NextButton: {
          props: ['label', 'type'],
          emits: ['click'],
          template:
            '<button :type="type" @click="$emit(\'click\')">{{ label }}</button>',
        },
        'woot-modal-header': {
          props: ['headerTitle', 'headerContent'],
          template:
            '<header><h2>{{ headerTitle }}</h2><p>{{ headerContent }}</p></header>',
        },
        'fluent-icon': true,
      },
      mocks: { $t: key => key },
    },
  });

  return { wrapper, dependencies, dispatch };
};

const openContextMenu = async wrapper => {
  await wrapper.findComponent(ConversationCard).trigger('contextmenu', {
    pageX: 100,
    pageY: 100,
  });
};

const findMenuAction = (wrapper, key) =>
  wrapper
    .findAllComponents(MenuItem)
    .find(item => item.props('option').key === key);

describe('ConversationItem contract shortcut', () => {
  it('renders the sidebar display name instead of the technical label slug', async () => {
    const { wrapper } = mountConversationItem();
    await openContextMenu(wrapper);

    const action = findMenuAction(wrapper, 'issue-contract');

    expect(action.text()).toBe('Emitir Contrato');
  });

  it('offers removal and highlights a conversation already routed to contracts', async () => {
    const { wrapper, dependencies } = mountConversationItem({
      labels: [{ title: 'emitir-contrato' }],
    });
    await openContextMenu(wrapper);

    const action = findMenuAction(wrapper, 'issue-contract');
    expect(action.text()).toBe('Remover etiqueta Emitir Contrato');
    expect(wrapper.findComponent(ConversationCard).classes()).toContain(
      'ring-2'
    );

    await action.trigger('click');
    await flushPromises();

    expect(dependencies.removeLabels).toHaveBeenCalledWith(
      ['emitir-contrato'],
      [2441]
    );
    expect(dependencies.assignLabels).not.toHaveBeenCalled();
  });

  it('assigns the canonical label slug while keeping the friendly menu title', async () => {
    const { wrapper, dependencies } = mountConversationItem();
    await openContextMenu(wrapper);

    const action = findMenuAction(wrapper, 'issue-contract');
    expect(action.text()).toBe('Emitir Contrato');
    await action.trigger('click');
    await flushPromises();

    expect(dependencies.assignLabels).toHaveBeenCalledWith(
      ['emitir-contrato'],
      [2441]
    );
    expect(dependencies.removeLabels).not.toHaveBeenCalled();
  });
});

describe('ConversationItem finalize confirmation', () => {
  const startFinalize = async wrapper => {
    await openContextMenu(wrapper);
    const action = findMenuAction(wrapper, 'finalize');
    expect(action).toBeTruthy();
    await action.trigger('click');
  };

  it('opens the confirmation before mutating the conversation', async () => {
    const { wrapper, dependencies, dispatch } = mountConversationItem({
      labels: [{ title: 'primeiro-contato' }],
    });

    await startFinalize(wrapper);

    const dialog = wrapper.get('[role="dialog"]');
    const confirmation = wrapper.findComponent(ConfirmationModal);
    expect(confirmation.props('title')).toBe(
      'CONVERSATION.CARD_CONTEXT_MENU.FINALIZE_CONFIRM_TITLE'
    );
    expect(confirmation.props('description')).toBe(
      'CONVERSATION.CARD_CONTEXT_MENU.FINALIZE_CONFIRM_DESCRIPTION'
    );
    expect(confirmation.vm.$attrs.size).toBe('medium');
    expect(confirmation.vm.show).toBe(true);
    expect(dialog.text()).toContain(
      'CONVERSATION.CARD_CONTEXT_MENU.FINALIZE_CANCEL'
    );
    expect(dialog.text()).toContain(
      'CONVERSATION.CARD_CONTEXT_MENU.FINALIZE_CONFIRM'
    );
    expect(dependencies.removeLabels).not.toHaveBeenCalled();
    expect(dependencies.assignLabels).not.toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it('does not change labels or status when confirmation is canceled', async () => {
    const { wrapper, dependencies, dispatch } = mountConversationItem({
      labels: [{ title: 'primeiro-contato' }],
    });

    await startFinalize(wrapper);
    await wrapper.get('[role="dialog"] button[type="reset"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[role="dialog"]').exists()).toBe(false);
    expect(dependencies.removeLabels).not.toHaveBeenCalled();
    expect(dependencies.assignLabels).not.toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalled();
  });

  it('moves the conversation to FINALIZADOS without changing native status', async () => {
    const { wrapper, dependencies, dispatch } = mountConversationItem({
      labels: [{ title: 'primeiro-contato' }],
    });

    await startFinalize(wrapper);
    await wrapper.get('[role="dialog"] button[type="submit"]').trigger('click');
    await flushPromises();

    expect(dependencies.removeLabels).toHaveBeenCalledOnce();
    expect(dependencies.removeLabels).toHaveBeenCalledWith(
      ['primeiro-contato'],
      [2441]
    );
    expect(dependencies.assignLabels).toHaveBeenCalledOnce();
    expect(dependencies.assignLabels).toHaveBeenCalledWith(
      ['FINALIZADOS'],
      [2441]
    );
    expect(dispatch).not.toHaveBeenCalled();
    expect(dependencies.updateConversationStatus).not.toHaveBeenCalled();
  });

  it('offers an explicit undo and removes FINALIZADOS without changing status', async () => {
    const { wrapper, dependencies, dispatch } = mountConversationItem({
      labels: [{ title: 'FINALIZADOS' }],
    });

    await openContextMenu(wrapper);
    const action = findMenuAction(wrapper, 'finalize');

    expect(action).toBeTruthy();
    expect(action.text()).toBe('CONVERSATION.CARD_CONTEXT_MENU.UNFINALIZE');

    await action.trigger('click');
    await flushPromises();

    expect(dependencies.removeLabels).toHaveBeenCalledWith(
      ['FINALIZADOS'],
      [2441]
    );
    expect(dependencies.assignLabels).not.toHaveBeenCalled();
    expect(wrapper.find('[role="dialog"]').exists()).toBe(false);
    expect(dispatch).not.toHaveBeenCalled();
    expect(dependencies.updateConversationStatus).not.toHaveBeenCalled();
  });

  it('offers undo while the finalized route is active before labels refresh', async () => {
    const { wrapper, dependencies } = mountConversationItem({
      routeLabel: 'finalizados',
    });

    await openContextMenu(wrapper);
    const action = findMenuAction(wrapper, 'finalize');

    expect(action.text()).toBe('CONVERSATION.CARD_CONTEXT_MENU.UNFINALIZE');
    await action.trigger('click');
    await flushPromises();

    expect(dependencies.removeLabels).toHaveBeenCalledWith(
      ['FINALIZADOS'],
      [2441]
    );
    expect(dependencies.assignLabels).not.toHaveBeenCalled();
  });

  it('archives by label only and leaves the native status untouched', async () => {
    const { wrapper, dependencies, dispatch } = mountConversationItem();
    await openContextMenu(wrapper);

    await findMenuAction(wrapper, 'archive').trigger('click');
    await flushPromises();

    expect(dependencies.assignLabels).toHaveBeenCalledWith(
      ['arquivado'],
      [2441]
    );
    expect(dependencies.updateConversationStatus).not.toHaveBeenCalled();
    expect(dispatch).not.toHaveBeenCalled();
  });
});
