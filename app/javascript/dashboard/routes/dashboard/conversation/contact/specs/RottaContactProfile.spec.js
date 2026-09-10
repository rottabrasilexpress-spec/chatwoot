import { mount } from '@vue/test-utils';

import RottaContactProfile from '../RottaContactProfile.vue';

const dispatch = vi.fn();

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/routes/dashboard/conversation/SharedFiles.vue', () => ({
  default: { template: '<div data-testid="shared-files" />' },
}));

describe('RottaContactProfile', () => {
  it('restores operational fields from the contact without replacing attachments', () => {
    const wrapper = mount(RottaContactProfile, {
      props: {
        contact: {
          id: 1862,
          custom_attributes: {
            rotta_move_profile: {
              origin: 'Brasília',
              destination: 'Salvador-Bahia',
              move_date: 'Entre 20 e 30 dias',
              items: 'Relação de bens no DOCX anexado',
            },
          },
        },
      },
    });

    expect(wrapper.text()).toContain('Perfil da mudança');
    expect(
      wrapper.find('input[placeholder="Cidade/UF de origem"]').element.value
    ).toBe('Brasília');
    expect(
      wrapper.find('input[placeholder="Cidade/UF de destino"]').element.value
    ).toBe('Salvador-Bahia');
    expect(wrapper.find('input[placeholder*="20 a 30"]').element.value).toBe(
      'Entre 20 e 30 dias'
    );
    expect(wrapper.text()).not.toContain('Anexos');
  });
});
