import { shallowMount } from '@vue/test-utils';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import ConversationCardExpanded from '../ConversationCardExpanded.vue';

const mountComponent = props =>
  shallowMount(ConversationCardExpanded, {
    props: {
      chat: { id: 1, labels: [], messages: [], status: 'open' },
      currentContact: { name: 'Jane Doe' },
      inbox: { id: 1 },
      ...props,
    },
  });

describe('ConversationCardExpanded selection', () => {
  it('keeps checkboxes hidden until bulk selection is active', () => {
    const wrapper = mountComponent();

    expect(wrapper.findComponent(Checkbox).exists()).toBe(false);
  });

  it('shows checkboxes for every card while bulk selection is active', () => {
    const wrapper = mountComponent({ selectionModeActive: true });

    expect(wrapper.findComponent(Checkbox).exists()).toBe(true);
  });
});
