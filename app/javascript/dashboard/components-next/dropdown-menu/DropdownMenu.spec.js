import { h } from 'vue';
import { mount } from '@vue/test-utils';
import DropdownMenu from './DropdownMenu.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('DropdownMenu contact cards', () => {
  it('renders a large known-contact card with a separate conversation action', async () => {
    const contact = {
      action: 'contact',
      icon: 'i-ri-whatsapp-fill',
      isContactCard: true,
      label: 'Kelvin (11965927865)',
      name: 'Kelvin',
      phoneNumber: '11965927865',
      secondaryAction: {
        label: 'Abrir conversa',
        icon: 'i-lucide-message-circle',
      },
      value: '1',
    };

    const wrapper = mount(DropdownMenu, {
      props: { menuItems: [contact] },
      slots: {
        label: ({ item }) =>
          h('span', { 'data-test': 'contact-label' }, item.name),
        'secondary-action': ({ item }) =>
          h(
            'span',
            { 'data-test': 'open-conversation-label' },
            item.secondaryAction.label
          ),
      },
      global: {
        stubs: {
          Avatar: true,
          EmojiIcon: true,
          Icon: true,
          Spinner: true,
        },
      },
    });

    expect(
      wrapper.get('[data-test="dropdown-contact-card"]').classes()
    ).toEqual(expect.arrayContaining(['min-h-16', 'min-w-[20rem]']));
    expect(wrapper.get('[data-test="contact-label"]').text()).toBe('Kelvin');
    expect(wrapper.get('button[aria-label="Abrir conversa"]')).toBeTruthy();

    await wrapper.get('button[aria-label="Abrir conversa"]').trigger('click');

    expect(wrapper.emitted('secondaryAction')).toEqual([[contact]]);
    expect(wrapper.emitted('action')).toBeUndefined();
  });
});
