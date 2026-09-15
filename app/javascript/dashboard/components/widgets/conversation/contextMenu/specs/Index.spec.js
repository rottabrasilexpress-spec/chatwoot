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

  it('does not show the contract shortcut when the conversation already has its label', () => {
    const wrapper = mountComponent({ canIssueContract: false });

    expect(
      wrapper
        .findAllComponents(MenuItem)
        .some(item => item.props('option').key === 'issue-contract')
    ).toBe(false);
  });
});
