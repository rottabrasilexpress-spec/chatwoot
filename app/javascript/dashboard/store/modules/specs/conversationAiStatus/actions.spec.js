import { createStore } from 'vuex';
import types from 'dashboard/store/mutation-types';
import conversationAiStatus, {
  conversationAiStatusPlugin,
} from 'dashboard/store/modules/conversationAiStatus';
import ConversationApi from 'dashboard/api/conversations';

vi.mock('dashboard/api/conversations', () => ({
  default: { getAiStatuses: vi.fn() },
}));

describe('conversationAiStatus store module', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('batches visible cards into one read and keeps failed status unknown', async () => {
    ConversationApi.getAiStatuses.mockResolvedValue({
      data: {
        statuses: [
          { conversation_id: '10', state: 'active' },
          { conversation_id: '11', state: 'blocked' },
        ],
      },
    });
    const store = createStore({ modules: { conversationAiStatus } });

    store.dispatch('conversationAiStatus/ensure', 10);
    store.dispatch('conversationAiStatus/ensure', 11);
    await vi.advanceTimersByTimeAsync(50);

    expect(ConversationApi.getAiStatuses).toHaveBeenCalledTimes(1);
    expect(ConversationApi.getAiStatuses).toHaveBeenCalledWith(['10', '11']);
    expect(store.getters['conversationAiStatus/getStatus'](10).state).toBe(
      'active'
    );
    expect(store.getters['conversationAiStatus/getStatus'](11).state).toBe(
      'blocked'
    );
  });

  it('refreshes a conversation after a message arrives', async () => {
    ConversationApi.getAiStatuses.mockResolvedValue({ data: { statuses: [] } });
    const store = createStore({
      mutations: { [types.ADD_MESSAGE]: () => {} },
      modules: { conversationAiStatus },
      plugins: [conversationAiStatusPlugin],
    });
    store.dispatch('conversationAiStatus/subscribe', 21);
    store.commit(types.ADD_MESSAGE, { conversation_id: 21 });
    await vi.advanceTimersByTimeAsync(1050);

    expect(ConversationApi.getAiStatuses).toHaveBeenCalledWith(['21']);
    expect(store.getters['conversationAiStatus/getStatus'](21).state).toBe(
      'unknown'
    );
    store.dispatch('conversationAiStatus/unsubscribe', 21);
  });

  it('fails closed when the status service rejects', async () => {
    ConversationApi.getAiStatuses.mockRejectedValue(new Error('offline'));
    const store = createStore({ modules: { conversationAiStatus } });

    store.dispatch('conversationAiStatus/ensure', 22);
    await vi.advanceTimersByTimeAsync(50);

    expect(store.getters['conversationAiStatus/getStatus'](22).state).toBe(
      'unknown'
    );
  });

  it('does not request AI status for a message outside the displayed cards', async () => {
    ConversationApi.getAiStatuses.mockResolvedValue({ data: { statuses: [] } });
    const store = createStore({
      mutations: { [types.ADD_MESSAGE]: () => {} },
      modules: { conversationAiStatus },
      plugins: [conversationAiStatusPlugin],
    });
    store.commit(types.ADD_MESSAGE, { conversation_id: 99 });
    await vi.advanceTimersByTimeAsync(1050);
    expect(ConversationApi.getAiStatuses).not.toHaveBeenCalled();
  });

  it('keeps a displayed header subscribed until the last badge unmounts', async () => {
    ConversationApi.getAiStatuses.mockResolvedValue({ data: { statuses: [] } });
    const store = createStore({
      mutations: { [types.ADD_MESSAGE]: () => {} },
      modules: { conversationAiStatus },
      plugins: [conversationAiStatusPlugin],
    });
    store.dispatch('conversationAiStatus/subscribe', 98);
    store.dispatch('conversationAiStatus/subscribe', 98);
    store.dispatch('conversationAiStatus/unsubscribe', 98);
    store.commit(types.ADD_MESSAGE, { conversation_id: 98 });
    await vi.advanceTimersByTimeAsync(1050);
    expect(ConversationApi.getAiStatuses).toHaveBeenCalledTimes(1);
    store.dispatch('conversationAiStatus/unsubscribe', 98);
    ConversationApi.getAiStatuses.mockClear();
    store.commit(types.ADD_MESSAGE, { conversation_id: 98 });
    await vi.advanceTimersByTimeAsync(1050);
    expect(ConversationApi.getAiStatuses).not.toHaveBeenCalled();
  });

  it('drops a pending visual refresh when the conversation leaves the screen', async () => {
    ConversationApi.getAiStatuses.mockResolvedValue({ data: { statuses: [] } });
    const store = createStore({
      mutations: { [types.ADD_MESSAGE]: () => {} },
      modules: { conversationAiStatus },
      plugins: [conversationAiStatusPlugin],
    });
    store.dispatch('conversationAiStatus/subscribe', 97);
    store.commit(types.ADD_MESSAGE, { conversation_id: 97 });
    store.dispatch('conversationAiStatus/unsubscribe', 97);
    await vi.advanceTimersByTimeAsync(1050);
    expect(ConversationApi.getAiStatuses).not.toHaveBeenCalled();
  });

  it('rechecks a hidden cached status when its conversation is opened again', async () => {
    ConversationApi.getAiStatuses.mockResolvedValue({
      data: { statuses: [{ conversation_id: '96', state: 'active' }] },
    });
    const store = createStore({
      mutations: { [types.ADD_MESSAGE]: () => {} },
      modules: { conversationAiStatus },
      plugins: [conversationAiStatusPlugin],
    });
    store.dispatch('conversationAiStatus/ensure', 96);
    await vi.advanceTimersByTimeAsync(50);
    ConversationApi.getAiStatuses.mockClear();
    store.commit(types.ADD_MESSAGE, { conversation_id: 96 });
    await vi.advanceTimersByTimeAsync(1050);
    expect(ConversationApi.getAiStatuses).not.toHaveBeenCalled();
    expect(store.getters['conversationAiStatus/getStatus'](96).state).toBe(
      'unknown'
    );
    ConversationApi.getAiStatuses.mockResolvedValue({
      data: { statuses: [{ conversation_id: '96', state: 'blocked' }] },
    });
    store.dispatch('conversationAiStatus/subscribe', 96);
    store.dispatch('conversationAiStatus/ensure', 96);
    await vi.advanceTimersByTimeAsync(50);
    expect(store.getters['conversationAiStatus/getStatus'](96).state).toBe(
      'blocked'
    );
    store.dispatch('conversationAiStatus/unsubscribe', 96);
  });

  it('cancels an unsent badge read on unmount and can reopen it normally', async () => {
    ConversationApi.getAiStatuses.mockResolvedValue({ data: { statuses: [] } });
    const store = createStore({ modules: { conversationAiStatus } });
    store.dispatch('conversationAiStatus/subscribe', 95);
    store.dispatch('conversationAiStatus/ensure', 95);
    store.dispatch('conversationAiStatus/unsubscribe', 95);
    await vi.advanceTimersByTimeAsync(50);
    expect(ConversationApi.getAiStatuses).not.toHaveBeenCalled();
    store.dispatch('conversationAiStatus/subscribe', 95);
    store.dispatch('conversationAiStatus/ensure', 95);
    await vi.advanceTimersByTimeAsync(50);
    expect(ConversationApi.getAiStatuses).toHaveBeenCalledTimes(1);
    store.dispatch('conversationAiStatus/unsubscribe', 95);
  });

  it('does not query n8n for messages received in a hidden tab', async () => {
    const hidden = vi.spyOn(document, 'hidden', 'get').mockReturnValue(true);
    ConversationApi.getAiStatuses.mockResolvedValue({ data: { statuses: [] } });
    const store = createStore({
      mutations: { [types.ADD_MESSAGE]: () => {} },
      modules: { conversationAiStatus },
      plugins: [conversationAiStatusPlugin],
    });
    store.dispatch('conversationAiStatus/subscribe', 94);
    store.commit(types.ADD_MESSAGE, { conversation_id: 94 });
    await vi.advanceTimersByTimeAsync(1050);
    const calls = ConversationApi.getAiStatuses.mock.calls.length;
    store.dispatch('conversationAiStatus/unsubscribe', 94);
    hidden.mockRestore();
    expect(calls).toBe(0);
  });

  it('invalidates a scheduled refresh if the agent hides the tab before it runs', async () => {
    const hidden = vi.spyOn(document, 'hidden', 'get').mockReturnValue(false);
    ConversationApi.getAiStatuses.mockResolvedValue({
      data: { statuses: [{ conversation_id: '93', state: 'active' }] },
    });
    const store = createStore({
      mutations: { [types.ADD_MESSAGE]: () => {} },
      modules: { conversationAiStatus },
      plugins: [conversationAiStatusPlugin],
    });
    store.dispatch('conversationAiStatus/subscribe', 93);
    store.dispatch('conversationAiStatus/ensure', 93);
    await vi.advanceTimersByTimeAsync(50);
    ConversationApi.getAiStatuses.mockClear();
    store.commit(types.ADD_MESSAGE, { conversation_id: 93 });
    hidden.mockReturnValue(true);
    await vi.advanceTimersByTimeAsync(1050);
    expect(ConversationApi.getAiStatuses).not.toHaveBeenCalled();
    expect(store.getters['conversationAiStatus/getStatus'](93).fetchedAt).toBe(
      0
    );
    store.dispatch('conversationAiStatus/unsubscribe', 93);
    hidden.mockRestore();
  });

  it('ignores an older in-flight response after a fresh refresh', async () => {
    let resolveFirst;
    let resolveSecond;
    const firstRequest = new Promise(resolve => {
      resolveFirst = resolve;
    });
    const secondRequest = new Promise(resolve => {
      resolveSecond = resolve;
    });
    ConversationApi.getAiStatuses
      .mockReturnValueOnce(firstRequest)
      .mockReturnValueOnce(secondRequest);
    const store = createStore({ modules: { conversationAiStatus } });

    store.dispatch('conversationAiStatus/ensure', 23);
    await vi.advanceTimersByTimeAsync(50);
    store.dispatch('conversationAiStatus/refresh', 23);
    await vi.advanceTimersByTimeAsync(50);

    resolveSecond({
      data: { statuses: [{ conversation_id: '23', state: 'blocked' }] },
    });
    await Promise.resolve();
    await Promise.resolve();
    expect(store.getters['conversationAiStatus/getStatus'](23).state).toBe(
      'blocked'
    );

    resolveFirst({
      data: { statuses: [{ conversation_id: '23', state: 'active' }] },
    });
    await Promise.resolve();
    await Promise.resolve();

    expect(store.getters['conversationAiStatus/getStatus'](23).state).toBe(
      'blocked'
    );
  });
});
