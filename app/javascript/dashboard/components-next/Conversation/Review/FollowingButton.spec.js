import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import FollowingButton from './FollowingButton.vue';
import { useConversationFollowing } from 'dashboard/composables/useConversationFollowing';
import { useAlert } from 'dashboard/composables';
vi.mock('dashboard/composables/useConversationFollowing', () => ({
  useConversationFollowing: vi.fn(),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
let service;
beforeEach(() => {
  service = {
    session: ref({ flags: { 7: false }, busy: {}, error: '' }),
    status: vi.fn(),
    setFollowing: vi.fn().mockResolvedValue(true),
  };
  useConversationFollowing.mockReturnValue(service);
  vi.clearAllMocks();
});
it('includes and removes with the same button and success notification', async () => {
  const wrapper = mount(FollowingButton, { props: { conversationId: 7 } });
  await wrapper.find('button').trigger('click');
  await flushPromises();
  expect(service.setFollowing).toHaveBeenLastCalledWith(7, true);
  expect(useAlert).toHaveBeenLastCalledWith(
    expect.stringContaining('adicionado')
  );
  service.session.value.flags[7] = true;
  await wrapper.vm.$nextTick();
  await wrapper.find('button').trigger('click');
  await flushPromises();
  expect(service.setFollowing).toHaveBeenLastCalledWith(7, false);
  expect(useAlert).toHaveBeenLastCalledWith(
    expect.stringContaining('retirado')
  );
});
it('does not show success when saving fails', async () => {
  service.setFollowing.mockResolvedValue(false);
  service.session.value.error = 'Falha';
  const wrapper = mount(FollowingButton, { props: { conversationId: 7 } });
  await wrapper.find('button').trigger('click');
  await flushPromises();
  expect(useAlert).toHaveBeenLastCalledWith('Falha');
});
it('waits for confirmed status and offers retry when unavailable', async () => {
  service.session.value.flags = {};
  service.session.value.error = 'Falha';
  const wrapper = mount(FollowingButton, { props: { conversationId: 7 } });
  expect(wrapper.find('button').attributes('disabled')).toBeDefined();
  await wrapper.findAll('button')[1].trigger('click');
  expect(service.status).toHaveBeenCalledWith(7);
});
