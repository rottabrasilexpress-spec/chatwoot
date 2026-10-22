import CopilotMessagesAPI from 'dashboard/api/captain/copilotMessages';
import { throwErrorMessage } from 'dashboard/store/utils/api';
import { createStore } from '../storeFactory';

const latestRequestByThread = new Map();

export default createStore({
  name: 'CopilotMessages',
  API: CopilotMessagesAPI,
  getters: {
    getMessagesByThreadId: state => copilotThreadId => {
      return state.records
        .filter(record => record.copilot_thread?.id === Number(copilotThreadId))
        .sort((a, b) => a.id - b.id);
    },
  },
  actions: mutationTypes => ({
    async get({ commit, state }, request) {
      const { threadId, afterId } =
        typeof request === 'object' ? request : { threadId: request };
      commit(mutationTypes.SET_UI_FLAG, { fetchingList: true });
      const normalizedThreadId = Number(threadId);
      const requestId =
        (latestRequestByThread.get(normalizedThreadId) || 0) + 1;
      latestRequestByThread.set(normalizedThreadId, requestId);

      try {
        const response = await CopilotMessagesAPI.get(threadId, { afterId });
        const payload = response.data?.payload || [];

        // A slower response from the same thread must not overwrite a newer one.
        if (latestRequestByThread.get(normalizedThreadId) === requestId) {
          const retainedRecords = afterId
            ? state.records
            : state.records.filter(
                record =>
                  Number(record.copilot_thread?.id) !== normalizedThreadId
              );
          const records = new Map(
            retainedRecords.map(record => [record.id, record])
          );
          payload.forEach(record => records.set(record.id, record));
          commit(mutationTypes.SET, [...records.values()]);
          commit(mutationTypes.SET_META, response.data?.meta);
        }

        return payload;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        commit(mutationTypes.SET_UI_FLAG, { fetchingList: false });
      }
    },
    upsert({ commit }, data) {
      commit(mutationTypes.UPSERT, data);
    },
  }),
});
