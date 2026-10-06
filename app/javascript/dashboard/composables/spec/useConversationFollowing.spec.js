import { reactive } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useStore } from 'vuex';
vi.mock('vuex', () => ({ useStore: vi.fn() }));
let service, wrapper, store, emitter;
beforeEach(async () => {
  vi.resetModules();
  ({ emitter } = await import('shared/helpers/mitt'));
  vi.useFakeTimers();
  store = reactive({
    getters: { getCurrentAccountId: 1, getCurrentUser: { id: 1 } },
  });
  useStore.mockReturnValue(store);
  globalThis.axios = {
    get: vi
      .fn()
      .mockResolvedValue({ data: { items: [], page: 1, has_more: false } }),
    patch: vi.fn().mockResolvedValue({ data: { following: true } }),
    delete: vi.fn().mockResolvedValue({ data: { following: false } }),
  };
  const { useConversationFollowing } = await import(
    '../useConversationFollowing'
  );
  wrapper = mount({
    setup() {
      service = useConversationFollowing({ panel: true });
      return {};
    },
    template: '<div />',
  });
});
afterEach(() => {
  wrapper.unmount();
  vi.useRealTimers();
  vi.clearAllMocks();
});
it('uses a shared backend resource, never labels or send endpoints', async () => {
  await service.setFollowing(7, true);
  expect(axios.patch).toHaveBeenCalledWith(
    '/api/v1/accounts/1/conversation_followings/7',
    {},
    { timeout: 10000 }
  );
  await service.setFollowing(7, false);
  expect(axios.delete).toHaveBeenCalledWith(
    '/api/v1/accounts/1/conversation_followings/7',
    { timeout: 10000 }
  );
  expect(service.session.value.flags[7]).toBe(false);
});
it('prevents duplicate writes on rapid repeated click', async () => {
  await Promise.all([
    service.setFollowing(7, true),
    service.setFollowing(7, true),
  ]);
  expect(axios.patch).toHaveBeenCalledTimes(1);
});
it('does not claim success on backend failure', async () => {
  axios.patch.mockRejectedValueOnce(new Error('offline'));
  expect(await service.setFollowing(7, true)).toBe(false);
  expect(service.session.value.flags[7]).toBeUndefined();
  expect(service.session.value.error).toContain('Não foi possível');
});
it('isolates cached flags across agents and accounts', async () => {
  await service.setFollowing(7, true);
  store.getters.getCurrentAccountId = 2;
  expect(service.session.value.flags[7]).toBeUndefined();
});
it('coalesces simultaneous reads and has no polling timer', async () => {
  await Promise.all([service.load(), service.load(), service.load()]);
  await vi.advanceTimersByTimeAsync(60000);
  expect(axios.get).toHaveBeenCalledTimes(1);
});
it('updates last public message but ignores private notes and older messages', async () => {
  service.session.value.items = [
    { id: 7, last_message: { id: 10, content: 'Original' } },
  ];
  emitter.emit('rotta:following-message', {
    account_id: 1,
    conversation_id: 7,
    id: 11,
    message_type: 1,
    private: true,
    content: 'Privado',
  });
  expect(service.session.value.items[0].last_message.content).toBe('Original');
  emitter.emit('rotta:following-message', {
    account_id: 1,
    conversation_id: 7,
    id: 12,
    message_type: 0,
    content: 'Cliente',
  });
  expect(service.session.value.items[0].last_message.content).toBe('Cliente');
  emitter.emit('rotta:following-message', {
    account_id: 1,
    conversation_id: 7,
    id: 9,
    message_type: 1,
    content: 'Antigo',
  });
  expect(service.session.value.items[0].last_message.content).toBe('Cliente');
});
it('reflects shared removals without modifying the conversation', async () => {
  service.session.value.items = [{ id: 7 }];
  emitter.emit('rotta:following-changed', {
    account_id: 1,
    id: 7,
    following: false,
  });
  expect(service.session.value.items).toHaveLength(0);
  expect(axios.delete).not.toHaveBeenCalled();
  await vi.advanceTimersByTimeAsync(501);
  await flushPromises();
  expect(axios.get).toHaveBeenCalledTimes(1);
});
it('keeps a socket message newer than an in-flight list read', async () => {
  service.session.value.items = [
    { id: 7, last_message: { id: 10, content: 'Old' } },
  ];
  let resolve;
  axios.get.mockImplementationOnce(
    () =>
      new Promise(done => {
        resolve = done;
      })
  );
  const loading = service.load();
  emitter.emit('rotta:following-message', {
    account_id: 1,
    conversation_id: 7,
    id: 12,
    message_type: 0,
    content: 'New',
  });
  resolve({
    data: {
      items: [{ id: 7, last_message: { id: 10, content: 'Old' } }],
      has_more: false,
    },
  });
  await loading;
  expect(service.session.value.items[0].last_message.content).toBe('New');
});
it('uses a stable cursor after removal while loading more', async () => {
  axios.get.mockResolvedValueOnce({
    data: { items: [{ id: 7 }], next_cursor: 31, has_more: true },
  });
  await service.load();
  service.session.value.items = [];
  await service.load(true);
  expect(axios.get).toHaveBeenLastCalledWith(
    '/api/v1/accounts/1/conversation_followings',
    { params: { before_id: 31 }, timeout: 10000 }
  );
});
