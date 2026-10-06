import { reactive } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import ConversationApi from '../../api/inbox/conversation';
vi.mock('vuex', () => ({ useStore: vi.fn() }));
vi.mock('vue-router', () => ({ useRouter: vi.fn() }));
vi.mock('../../api/inbox/conversation', () => ({ default: { show: vi.fn() } }));
const context = {
  label: '',
  conversationType: '',
  status: 'all',
  assigneeType: 'all',
  filters: [],
};
const chats = ['Francine', 'Eldon', 'Graziela'].map((name, index) => ({
  id: index + 1,
  meta: { sender: { name } },
  labels: [],
  status: 'open',
}));
let review;
let store;
let push;
beforeEach(async () => {
  vi.resetModules();
  vi.useFakeTimers();
  store = reactive({
    getters: { getCurrentAccountId: 1, getCurrentUser: { id: 1 } },
  });
  useStore.mockReturnValue(store);
  push = vi.fn().mockResolvedValue(undefined);
  useRouter.mockReturnValue({ push });
  globalThis.axios = {
    get: vi.fn().mockResolvedValue({ data: { views: {}, history: [] } }),
    patch: vi.fn().mockImplementation(async (_url, { points }) => ({
      data: {
        views: Object.fromEntries(points.map(point => [point.view, point])),
        history: [...points].reverse().slice(0, 5),
      },
    })),
  };
  const module = await import('../useConversationReview');
  review = module.useConversationReview();
});
afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});
describe('automatic review persistence', () => {
  it('ignores an old GET arriving after a successful save', async () => {
    let resolveRead;
    axios.get.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          resolveRead = resolve;
        })
    );
    const loading = review.load();
    review.record(chats, chats[0], context, 'Todos');
    await review.flush();
    resolveRead({ data: { views: {}, history: [] } });
    await loading;
    expect(review.session.value.history[0].name).toBe('Francine');
  });
  it('does not navigate when the account changes during a candidate read', async () => {
    let resolveRead;
    review.record(chats, chats[0], context, 'Todos');
    ConversationApi.show.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          resolveRead = resolve;
        })
    );
    const resuming = review.resume(review.session.value.history[0]);
    store.getters.getCurrentAccountId = 2;
    resolveRead({ data: chats[1] });
    await resuming;
    expect(push).not.toHaveBeenCalled();
    expect(review.session.value.history).toHaveLength(0);
  });
  it('does not save into a new account after delayed navigation', async () => {
    let resolveNavigation;
    review.record(chats, chats[0], context, 'Todos');
    ConversationApi.show.mockResolvedValueOnce({ data: chats[1] });
    push.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          resolveNavigation = resolve;
        })
    );
    const resuming = review.resume(review.session.value.history[0]);
    await vi.waitFor(() => expect(push).toHaveBeenCalled());
    store.getters.getCurrentAccountId = 2;
    resolveNavigation();
    await resuming;
    expect(review.session.value.history).toHaveLength(0);
  });
  it('groups rapid clicks in one write and retains their history', async () => {
    chats.forEach(chat => review.record(chats, chat, context, 'Todos'));
    expect(review.session.value.history).toHaveLength(3);
    await vi.advanceTimersByTimeAsync(201);
    expect(axios.patch).toHaveBeenCalledTimes(1);
    expect(axios.patch.mock.calls[0][1].points).toHaveLength(3);
    expect(review.session.value.views[JSON.stringify(context)].name).toBe(
      'Graziela'
    );
  });
  it('keeps an unsaved point and shows a retryable error', async () => {
    axios.patch.mockRejectedValueOnce(new Error('offline'));
    review.record(chats, chats[0], context, 'Todos');
    await review.flush();
    expect(review.session.value.pending).toHaveLength(1);
    expect(review.session.value.error).toContain('não foi salvo');
    await review.flush();
    expect(review.session.value.pending).toHaveLength(0);
    expect(review.session.value.error).toBe('');
  });
  it('keeps each agent and account isolated even across a delayed save', async () => {
    review.record(chats, chats[0], context, 'Todos');
    store.getters.getCurrentAccountId = 2;
    store.getters.getCurrentUser.id = 9;
    expect(review.session.value.history).toHaveLength(0);
    await vi.advanceTimersByTimeAsync(201);
    expect(axios.patch.mock.calls[0][0]).toBe(
      '/api/v1/accounts/1/review_points'
    );
  });
  it('reads once when several components load the same session', async () => {
    await Promise.all([review.load(), review.load(), review.load()]);
    expect(axios.get).toHaveBeenCalledTimes(1);
  });
  it('resumes Eldon and advances to Graziela without recapturing the live order', async () => {
    review.record(chats, chats[0], context, 'Todos');
    ConversationApi.show.mockResolvedValueOnce({ data: chats[1] });
    await review.resume(review.session.value.history[0]);
    expect(push.mock.calls[0][0].path).toBe('/app/accounts/1/conversations/2');
    expect(review.session.value.history[0].remaining[0].name).toBe('Graziela');
    expect(review.session.value.history).toHaveLength(1);
  });
  it('skips an archived next contact without modifying that contact', async () => {
    review.record(chats, chats[0], context, 'Todos');
    ConversationApi.show
      .mockResolvedValueOnce({ data: { ...chats[1], labels: ['arquivado'] } })
      .mockResolvedValueOnce({ data: chats[2] });
    await review.resume(review.session.value.history[0]);
    expect(push.mock.calls[0][0].path).toBe('/app/accounts/1/conversations/3');
    expect(review.session.value.history[0].remaining).toHaveLength(0);
  });
  it('does not advance on a network failure or send a client message', async () => {
    review.record(chats, chats[0], context, 'Todos');
    ConversationApi.show.mockRejectedValueOnce(new Error('network'));
    await review.resume(review.session.value.history[0]);
    expect(push).not.toHaveBeenCalled();
    expect(review.session.value.history[0].remaining).toHaveLength(2);
    expect(review.session.value.error).toContain('Não foi possível abrir');
  });
  it('does not open two chats on a double click', async () => {
    review.record(chats, chats[0], context, 'Todos');
    ConversationApi.show.mockResolvedValueOnce({ data: chats[1] });
    await Promise.all([
      review.resume(review.session.value.history[0]),
      review.resume(review.session.value.history[0]),
    ]);
    expect(ConversationApi.show).toHaveBeenCalledTimes(1);
    expect(push).toHaveBeenCalledTimes(1);
  });
  it('keeps the next shortcut on Todos after resuming an old budget point', async () => {
    const budget = {
      ...context,
      label: 'kelvin',
      inboxId: 0,
      teamId: 0,
      foldersId: 0,
    };
    review.record(chats, chats[0], budget, '#kelvin');
    ConversationApi.show.mockResolvedValueOnce({
      data: { ...chats[1], labels: ['kelvin'] },
    });
    await review.resume(review.session.value.history[0]);
    expect(push.mock.calls[0][0].path).toBe('/app/accounts/1/conversations/2');
    const point = review.session.value.history[0];
    expect(point.context.label).toBe('');
    expect(point.title).toBe('Todos');
    expect(review.session.value.views[point.view].remaining[0].name).toBe(
      'Graziela'
    );
  });
});
