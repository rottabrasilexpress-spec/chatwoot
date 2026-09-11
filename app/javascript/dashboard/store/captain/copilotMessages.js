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
    async get({ commit, state }, threadId) {
      commit(mutationTypes.SET_UI_FLAG, { fetchingList: true });
      const normalizedThreadId = Number(threadId);
      const requestId =
        (latestRequestByThread.get(normalizedThreadId) || 0) + 1;
      latestRequestByThread.set(normalizedThreadId, requestId);

      try {
        const response = await CopilotMessagesAPI.get(threadId);
        const payload = response.data?.payload || [];

        // A slower response from the same thread must not overwrite a newer one.
        if (latestRequestByThread.get(normalizedThreadId) === requestId) {
          const recordsFromOtherThreads = state.records.filter(
            record => Number(record.copilot_thread?.id) !== normalizedThreadId
          );
          commit(mutationTypes.SET, [...recordsFromOtherThreads, ...payload]);
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
