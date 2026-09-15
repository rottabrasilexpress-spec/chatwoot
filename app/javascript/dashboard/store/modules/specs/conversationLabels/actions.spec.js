import axios from 'axios';
import { actions } from '../../conversationLabels';
import * as types from '../../../mutation-types';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  beforeEach(() => {
    commit.mockClear();
    axios.get.mockReset();
    axios.post.mockReset();
  });

  describe('#get', () => {
    it('sends correct actions if API is success', async () => {
      axios.get.mockResolvedValue({
        data: { payload: ['customer-success', 'on-hold'] },
      });
      await actions.get({ commit }, 1);
      expect(commit.mock.calls).toEqual([
        [types.default.SET_CONVERSATION_LABELS_UI_FLAG, { isFetching: true }],

        [
          types.default.SET_CONVERSATION_LABELS,
          { id: 1, data: ['customer-success', 'on-hold'] },
        ],
        [types.default.SET_CONVERSATION_LABELS_UI_FLAG, { isFetching: false }],
      ]);
    });
    it('sends correct actions if API is error', async () => {
      axios.get.mockRejectedValue({ message: 'Incorrect header' });
      await actions.get({ commit });
      expect(commit.mock.calls).toEqual([
        [types.default.SET_CONVERSATION_LABELS_UI_FLAG, { isFetching: true }],
        [types.default.SET_CONVERSATION_LABELS_UI_FLAG, { isFetching: false }],
      ]);
    });
  });

  describe('#update', () => {
    it('updates correct actions if API is success', async () => {
      axios.post.mockResolvedValue({
        data: { payload: ['on-hold'] },
      });
      await actions.update(
        { commit },
        { conversationId: '1', labels: ['on-hold'] }
      );

      expect(commit.mock.calls).toEqual([
        [types.default.SET_CONVERSATION_LABELS_UI_FLAG, { isUpdating: true }],
        [types.default.SET_CONVERSATION_LABELS, { id: '1', data: ['on-hold'] }],
        [types.default.SET_CONVERSATION_LABELS, { id: '1', data: ['on-hold'] }],
        [types.default.SET_CONVERSATION_LABELS_UI_FLAG, { isError: false }],
        [types.default.SET_CONVERSATION_LABELS_UI_FLAG, { isUpdating: false }],
      ]);
    });

    it('returns success only after the server confirms the update', async () => {
      axios.post.mockResolvedValue({
        data: { payload: ['on-hold'] },
      });

      await expect(
        actions.update({ commit }, { conversationId: '1', labels: ['on-hold'] })
      ).resolves.toBe(true);
    });

    it('sends correct actions if API is error', async () => {
      axios.post.mockRejectedValue({ message: 'Incorrect header' });
      await actions.update(
        { commit },
        { conversationId: '1', labels: ['on-hold'] }
      );
      expect(commit).toHaveBeenCalledWith(
        types.default.SET_CONVERSATION_LABELS_UI_FLAG,
        { isError: true }
      );
      expect(commit).toHaveBeenCalledWith(
        types.default.SET_CONVERSATION_LABELS_UI_FLAG,
        { isUpdating: false }
      );
    });

    it('returns false when the server rejects the update', async () => {
      axios.post.mockRejectedValue({ message: 'Incorrect header' });

      await expect(
        actions.update({ commit }, { conversationId: '1', labels: ['on-hold'] })
      ).resolves.toBe(false);
    });

    it('serializes rapid replacements and does not let an old response overwrite the latest intent', async () => {
      let resolveFirst;
      const records = {};
      const commitState = (type, payload) => {
        if (type === types.default.SET_CONVERSATION_LABELS) {
          records[payload.id] = payload.data;
        }
      };
      axios.post
        .mockImplementationOnce(
          () =>
            new Promise(resolve => {
              resolveFirst = resolve;
            })
        )
        .mockResolvedValueOnce({ data: { payload: ['final-label'] } });

      const first = actions.update(
        { commit: commitState },
        { conversationId: 'rapid-9042', labels: ['first-label'] }
      );
      const second = actions.update(
        { commit: commitState },
        { conversationId: 'rapid-9042', labels: ['final-label'] }
      );

      await vi.waitFor(() => expect(axios.post).toHaveBeenCalledTimes(1));
      expect(records['rapid-9042']).toEqual(['final-label']);

      resolveFirst({ data: { payload: ['first-label'] } });
      await Promise.all([first, second]);

      expect(axios.post).toHaveBeenCalledTimes(2);
      expect(axios.post.mock.calls.map(([, body]) => body.labels)).toEqual([
        ['first-label'],
        ['final-label'],
      ]);
      expect(records['rapid-9042']).toEqual(['final-label']);
    });
  });

  describe('#mutate', () => {
    it('reads the saved labels before applying an additive change', async () => {
      axios.get.mockResolvedValue({
        data: { payload: ['primeiro-contato'] },
      });
      axios.post.mockResolvedValue({
        data: { payload: ['primeiro-contato', 'emitir-contrato'] },
      });

      await expect(
        actions.mutate(
          {
            commit,
            dispatch: vi.fn(),
            rootGetters: { getConversationById: () => null },
          },
          { conversationId: 'mutation-301', add: ['emitir-contrato'] }
        )
      ).resolves.toBe(true);

      expect(axios.get).toHaveBeenCalledWith(
        '/api/v1/conversations/mutation-301/labels'
      );
      expect(axios.post).toHaveBeenCalledWith(
        '/api/v1/conversations/mutation-301/labels',
        { labels: ['primeiro-contato', 'emitir-contrato'] }
      );
    });

    it('serializes a rapid add then remove against the latest persisted state', async () => {
      axios.get
        .mockResolvedValueOnce({ data: { payload: [] } })
        .mockResolvedValueOnce({ data: { payload: ['emitir-contrato'] } });
      axios.post
        .mockResolvedValueOnce({ data: { payload: ['emitir-contrato'] } })
        .mockResolvedValueOnce({ data: { payload: [] } });

      const dependencies = {
        commit,
        dispatch: vi.fn(),
        rootGetters: { getConversationById: () => null },
      };
      const add = actions.mutate(dependencies, {
        conversationId: 'mutation-302',
        add: ['emitir-contrato'],
      });
      const remove = actions.mutate(dependencies, {
        conversationId: 'mutation-302',
        remove: ['emitir-contrato'],
      });

      await Promise.all([add, remove]);

      expect(axios.get).toHaveBeenCalledTimes(2);
      expect(axios.post.mock.calls.map(([, body]) => body.labels)).toEqual([
        ['emitir-contrato'],
        [],
      ]);
    });
  });

  describe('#setBulkConversationLabels', () => {
    it('it send correct mutations', () => {
      actions.setBulkConversationLabels({ commit }, [
        { id: 1, labels: ['customer-support'] },
      ]);
      expect(commit.mock.calls).toEqual([
        [
          types.default.SET_BULK_CONVERSATION_LABELS,
          [{ id: 1, labels: ['customer-support'] }],
        ],
      ]);
    });
  });

  describe('#setBulkConversationLabels', () => {
    it('it send correct mutations', () => {
      actions.setConversationLabel(
        { commit },
        { id: 1, data: ['customer-support'] }
      );
      expect(commit.mock.calls).toEqual([
        [
          types.default.SET_CONVERSATION_LABELS,
          { id: 1, data: ['customer-support'] },
        ],
      ]);
    });
  });
});
