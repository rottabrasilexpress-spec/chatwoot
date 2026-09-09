import { mount } from '@vue/test-utils';
import Snackbar from './Snackbar.vue';

describe('Snackbar', () => {
  it('renders archive warnings with the danger background', () => {
    const wrapper = mount(Snackbar, {
      props: {
        message: 'Conversa arquivada',
        action: { variant: 'danger' },
      },
      global: { stubs: { 'router-link': true } },
    });

    expect(wrapper.find('.shadow-sm').classes()).toContain('bg-n-ruby-9');
  });

  it('keeps ordinary notifications on the neutral background', () => {
    const wrapper = mount(Snackbar, {
      props: { message: 'Etiqueta atualizada' },
      global: { stubs: { 'router-link': true } },
    });

    expect(wrapper.find('.shadow-sm').classes()).toContain('bg-n-slate-12');
  });
});
