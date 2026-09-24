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

    store.commit(types.ADD_MESSAGE, { conversation_id: 21 });
    await vi.advanceTimersByTimeAsync(1050);

    expect(ConversationApi.getAiStatuses).toHaveBeenCalledWith(['21']);
    expect(store.getters['conversationAiStatus/getStatus'](21).state).toBe(
      'unknown'
    );
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
