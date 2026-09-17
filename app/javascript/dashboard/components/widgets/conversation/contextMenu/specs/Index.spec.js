import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ConversationContextMenu from '../Index.vue';
import MenuItem from '../menuItem.vue';

const mountComponent = props =>
  mount(ConversationContextMenu, {
    props: {
      chatId: 42,
      canIssueContract: true,
      contractLabelTitle: 'Emitir Contrato',
      ...props,
    },
    global: {
      plugins: [
        createStore({
          getters: { getCurrentRole: () => 'agent' },
          modules: {
            labels: {
              namespaced: true,
              getters: { getLabels: () => [] },
            },
          },
        }),
      ],
      mocks: { $t: key => key },
      stubs: { 'fluent-icon': true },
    },
  });

describe('ConversationContextMenu', () => {
  it('shows the purple contract label shortcut and emits the assignment action', async () => {
    const wrapper = mountComponent();
    const action = wrapper
      .findAllComponents(MenuItem)
      .find(item => item.props('option').key === 'issue-contract');

    expect(action).toBeTruthy();
    expect(action.props('variant')).toBe('contract');
    expect(action.props('option')).toMatchObject({
      label: 'Emitir Contrato',
    });
    expect(action.get('.menu-label').classes()).toContain('text-violet-600');

    await action.trigger('click');

    expect(wrapper.emitted('issueContract')).toEqual([[42]]);
    expect(wrapper.emitted('close')).toEqual([[]]);
  });

  it('shows a remove action when the conversation already has its label', () => {
    const wrapper = mountComponent({ contractLabelAssigned: true });

    const action = wrapper
      .findAllComponents(MenuItem)
      .find(item => item.props('option').key === 'issue-contract');

    expect(action.text()).toBe('Remover etiqueta Emitir Contrato');
  });

  it('shows an explicit undo action for a finalized conversation', () => {
    const wrapper = mountComponent({
      canFinalize: true,
      finalizedLabelAssigned: true,
    });

    const action = wrapper
      .findAllComponents(MenuItem)
      .find(item => item.props('option').key === 'finalize');

    expect(action).toBeTruthy();
    expect(action.props('option')).toMatchObject({
      label: 'CONVERSATION.CARD_CONTEXT_MENU.UNFINALIZE',
      icon: 'i-lucide-undo-2',
    });
  });
});
