import { createStore as createVuexStore } from 'vuex';

const copilotMessagesApi = vi.hoisted(() => ({
  get: vi.fn(),
}));

vi.mock('dashboard/api/captain/copilotMessages', () => ({
  default: copilotMessagesApi,
}));

import CopilotMessagesAPI from 'dashboard/api/captain/copilotMessages';
import copilotMessages from './copilotMessages';

const makeMessage = (id, threadId, content) => ({
  id,
  message: { content },
  message_type: 'assistant',
  copilot_thread: { id: threadId },
});

const makeStore = () => createVuexStore({ modules: { copilotMessages } });

describe('copilotMessages store', () => {
  beforeEach(() => {
    CopilotMessagesAPI.get.mockReset();
  });

  it('keeps messages from each conversation when GET responses finish out of order', async () => {
    let resolveFirst;
    let resolveSecond;
    CopilotMessagesAPI.get
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveFirst = resolve;
          })
      )
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveSecond = resolve;
          })
      );

    const store = makeStore();
    const firstRequest = store.dispatch('copilotMessages/get', 101);
    const secondRequest = store.dispatch('copilotMessages/get', 202);

    resolveSecond({
      data: {
        payload: [makeMessage(2, 202, 'resposta do chat 202')],
        meta: { total_count: 1, page: 1 },
      },
    });
    await secondRequest;

    resolveFirst({
      data: {
        payload: [makeMessage(1, 101, 'resposta do chat 101')],
        meta: { total_count: 1, page: 1 },
      },
    });
    await firstRequest;

    expect(store.state.copilotMessages.records).toEqual([
      makeMessage(2, 202, 'resposta do chat 202'),
      makeMessage(1, 101, 'resposta do chat 101'),
    ]);
  });

  it('ignores an older GET response for the same conversation thread', async () => {
    let resolveStale;
    let resolveFresh;
    CopilotMessagesAPI.get
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveStale = resolve;
          })
      )
      .mockImplementationOnce(
        () =>
          new Promise(resolve => {
            resolveFresh = resolve;
          })
      );

    const store = makeStore();
    const staleRequest = store.dispatch('copilotMessages/get', 303);
    const freshRequest = store.dispatch('copilotMessages/get', 303);

    resolveFresh({
      data: {
        payload: [makeMessage(3, 303, 'resposta mais nova')],
        meta: { total_count: 1, page: 1 },
      },
    });
    await freshRequest;

    resolveStale({
      data: {
        payload: [makeMessage(4, 303, 'resposta obsoleta')],
        meta: { total_count: 1, page: 1 },
      },
    });
    await staleRequest;

    expect(
      store.state.copilotMessages.records.filter(
        record => record.copilot_thread.id === 303
      )
    ).toEqual([makeMessage(3, 303, 'resposta mais nova')]);
  });
});
