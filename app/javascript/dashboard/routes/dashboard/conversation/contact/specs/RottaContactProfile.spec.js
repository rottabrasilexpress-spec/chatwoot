import { flushPromises, mount } from '@vue/test-utils';

import RottaContactProfile from '../RottaContactProfile.vue';
import ConversationAiAPI from 'dashboard/api/captain/conversationAi';

const dispatch = vi.fn();

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('dashboard/api/captain/conversationAi', () => ({
  default: {
    profile: vi.fn(),
  },
}));

vi.mock('dashboard/routes/dashboard/conversation/SharedFiles.vue', () => ({
  default: { template: '<div data-testid="shared-files" />' },
}));

describe('RottaContactProfile', () => {
  beforeEach(() => {
    dispatch.mockReset();
    ConversationAiAPI.profile.mockReset();
  });

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

  it('fills the profile through the isolated conversation AI action', async () => {
    ConversationAiAPI.profile.mockResolvedValue({
      data: {
        ok: true,
        profile: {
          origin: 'Brasília',
          destination: 'Salvador',
          move_date: '25/10/2026',
          budget_value: '',
          items: '',
          observations: '',
          helpers_origin: 0,
          helpers_destination: 0,
          assembly_items: '',
          disassembly_items: '',
        },
        changed_fields: ['origin', 'destination', 'move_date'],
      },
    });

    const wrapper = mount(RottaContactProfile, {
      props: {
        conversationId: 2165,
        contact: { id: 1862, custom_attributes: {} },
      },
    });

    await wrapper
      .find('button[aria-label="Preencher perfil da mudança com IA"]')
      .trigger('click');
    await flushPromises();

    expect(ConversationAiAPI.profile).toHaveBeenCalledWith(2165);
    expect(
      wrapper.find('input[placeholder="Cidade/UF de origem"]').element.value
    ).toBe('Brasília');
    expect(
      wrapper.find('input[placeholder="Cidade/UF de destino"]').element.value
    ).toBe('Salvador');
  });
});
