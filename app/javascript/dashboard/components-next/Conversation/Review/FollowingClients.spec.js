import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import FollowingClients from './FollowingClients.vue';
import { useConversationFollowing } from 'dashboard/composables/useConversationFollowing';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import ConversationApi from 'dashboard/api/inbox/conversation';
vi.mock('dashboard/composables/useConversationFollowing', () => ({
  useConversationFollowing: vi.fn(),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vuex', () => ({ useStore: vi.fn() }));
vi.mock('vue-router', () => ({ useRouter: vi.fn() }));
vi.mock('dashboard/api/inbox/conversation', () => ({
  default: { show: vi.fn() },
}));
let service, push;
const item = {
  id: 7,
  name: 'Francine',
  avatar_url: '',
  labels: ['kelvin'],
  last_message: { content: 'Qual o prazo?', message_type: 'incoming' },
};
beforeEach(() => {
  vi.clearAllMocks();
  service = {
    session: ref({ items: [item], busy: {}, loading: false, hasMore: true }),
    load: vi.fn(),
    setFollowing: vi.fn().mockResolvedValue(true),
  };
  useConversationFollowing.mockReturnValue(service);
  useStore.mockReturnValue({ getters: { getCurrentAccountId: 1 } });
  push = vi.fn();
  useRouter.mockReturnValue({ push });
  ConversationApi.show.mockResolvedValue({ data: item });
});
const mountPage = () =>
  mount(FollowingClients, { global: { stubs: { Avatar: true } } });
it('opens the card in Todos despite a budget trail label', async () => {
  const wrapper = mountPage();
  await wrapper
    .findAll('button')
    .find(b => b.text().includes('Francine'))
    .trigger('click');
  await flushPromises();
  expect(push).toHaveBeenCalledWith('/app/accounts/1/conversations/7');
});
it('checks fresh labels so a newly archived card never opens Todos', async () => {
  ConversationApi.show.mockResolvedValueOnce({
    data: { ...item, labels: ['arquivado'] },
  });
  const wrapper = mountPage();
  await wrapper
    .findAll('button')
    .find(b => b.text().includes('Francine'))
    .trigger('click');
  await flushPromises();
  expect(push).toHaveBeenCalledWith('/app/accounts/1/archived/conversations/7');
});
it('refresh, pagination and remove controls call their exact operations', async () => {
  const wrapper = mountPage();
  await wrapper
    .findAll('button')
    .find(b => b.text() === 'Atualizar clientes')
    .trigger('click');
  await wrapper
    .findAll('button')
    .find(b => b.text() === 'Mostrar mais clientes')
    .trigger('click');
  await wrapper
    .find('button[aria-label="Retirar Francine do acompanhamento"]')
    .trigger('click');
  expect(service.load).toHaveBeenCalledWith(true);
  expect(service.setFollowing).toHaveBeenCalledWith(7, false);
});
