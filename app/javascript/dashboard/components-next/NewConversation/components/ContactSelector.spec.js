import { computed, defineComponent } from 'vue';
import { shallowMount } from '@vue/test-utils';
import ContactSelector from './ContactSelector.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const TagInputStub = defineComponent({
  name: 'TagInput',
  props: {
    type: { type: String, default: '' },
    menuItems: { type: Array, default: () => [] },
    placeholder: { type: String, default: '' },
  },
  emits: ['input'],
  setup(props, { emit }) {
    const onInput = event => emit('input', event.target.value);
    const inputType = computed(() => props.type);
    const inputMenuItems = computed(() => props.menuItems);
    const inputPlaceholder = computed(() => props.placeholder);
    return { onInput, inputType, inputMenuItems, inputPlaceholder };
  },
  template:
    '<input data-test="contact-input" :data-input-type="inputType" :data-menu-count="inputMenuItems.length" :placeholder="inputPlaceholder" @input="onInput" />',
});

describe('ContactSelector', () => {
  const mountSelector = () =>
    shallowMount(ContactSelector, {
      props: {
        contacts: [
          {
            id: '1',
            name: 'Kelvin',
            phone_number: '11965927865',
            thumbnail: '',
          },
        ],
        selectedContact: null,
        showContactsDropdown: true,
        isLoading: false,
        isCreatingContact: false,
        contactId: null,
        contactableInboxesList: [],
        showInboxesDropdown: false,
      },
      global: {
        stubs: { TagInput: TagInputStub, Button: true },
      },
    });

  it('switches plain Brazilian numbers to phone search and shows a WhatsApp result', async () => {
    const wrapper = mountSelector();
    const tagInput = wrapper.findComponent(TagInputStub);

    expect(tagInput.props('menuItems')[0]).toMatchObject({
      label: 'Kelvin (11965927865)',
      icon: 'i-ri-whatsapp-fill',
      phoneNumber: '11965927865',
    });

    await wrapper.get('[data-test="contact-input"]').setValue('11965927865');

    expect(tagInput.props('type')).toBe('tel');
    expect(wrapper.emitted('searchContacts')).toEqual([['11965927865']]);
  });
});
