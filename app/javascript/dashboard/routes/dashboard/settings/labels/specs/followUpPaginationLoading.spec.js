import { mount } from '@vue/test-utils';
import FollowUpPagination from '../FollowUpPagination.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const Button = {
  props: ['label', 'disabled'],
  emits: ['click'],
  template:
    '<button :disabled="disabled" @click="$emit(\'click\')">{{ label }}</button>',
};

describe('FollowUpPagination background loading', () => {
  it('accepts a page change while a background refresh is loading', async () => {
    const wrapper = mount(FollowUpPagination, {
      props: {
        pagination: { page: 2, per_page: 25, total: 100, total_pages: 4 },
        loading: true,
        label: 'Pages',
      },
      global: { stubs: { Button } },
    });
    const buttons = wrapper.findAll('button');
    expect(buttons.every(button => !button.element.disabled)).toBe(true);
    expect(wrapper.find('nav').attributes('aria-busy')).toBe('true');
    await buttons[1].trigger('click');
    expect(wrapper.emitted('page')).toEqual([[3]]);
    await buttons[0].trigger('click');
    expect(wrapper.emitted('page')).toEqual([[3], [1]]);
  });

  it('still prevents navigating outside the available pages', () => {
    const wrapper = mount(FollowUpPagination, {
      props: {
        pagination: { page: 1, per_page: 25, total: 1, total_pages: 1 },
        loading: false,
        label: 'Pages',
      },
      global: { stubs: { Button } },
    });
    expect(wrapper.findAll('button').every(button => button.element.disabled)).toBe(true);
  });
});
