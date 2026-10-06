import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import ReviewResume from './ReviewResume.vue';
import { useConversationReview } from 'dashboard/composables/useConversationReview';
vi.mock('dashboard/composables/useConversationReview', () => ({
  useConversationReview: vi.fn(),
}));
describe('review controls', () => {
  let service;
  const point = {
    id: 'one',
    title: 'Todos',
    name: 'Francine',
    remaining: [{ id: 2, name: 'Eldon' }],
  };
  beforeEach(() => {
    service = {
      session: ref({
        views: { all: point },
        history: [point],
        error: '',
        loaded: true,
      }),
      load: vi.fn(),
      flush: vi.fn(),
      resume: vi.fn(),
    };
    useConversationReview.mockReturnValue(service);
  });
  it('every history and tab button resumes its own point', async () => {
    const wrapper = mount(ReviewResume);
    const buttons = wrapper
      .findAll('button')
      .filter(button => button.text() === 'Continuar revisão');
    expect(buttons).toHaveLength(2);
    for (const button of buttons) await button.trigger('click');
    expect(service.resume).toHaveBeenCalledTimes(2);
    expect(service.resume).toHaveBeenLastCalledWith(point);
  });
  it('refresh and retry flush before reading server state', async () => {
    service.session.value.error = 'Falha';
    const wrapper = mount(ReviewResume);
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Atualizar pontos')
      .trigger('click');
    await wrapper
      .findAll('button')
      .find(button => button.text() === 'Tentar novamente')
      .trigger('click');
    expect(service.flush).toHaveBeenCalledTimes(3);
    expect(service.load).toHaveBeenLastCalledWith(true);
  });
  it('the compact shortcut opens the saved next contact', async () => {
    const wrapper = mount(ReviewResume, {
      props: { compact: true, view: 'all' },
    });
    expect(wrapper.text()).toContain('Próximo: Eldon');
    await wrapper.find('button').trigger('click');
    expect(service.resume).toHaveBeenCalledWith(point);
  });
  it('disables exhausted sequences and concurrent navigation', () => {
    service.session.value.busy = true;
    const wrapper = mount(ReviewResume);
    expect(
      wrapper
        .findAll('button')
        .every(button => button.attributes('disabled') !== undefined)
    ).toBe(true);
  });
});
