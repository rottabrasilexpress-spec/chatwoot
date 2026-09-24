import ConversationApi from 'dashboard/api/conversations';
import types from 'dashboard/store/mutation-types';

const STATUS_TTL_MS = 20000;
const BATCH_SIZE = 100;
const BATCH_DELAY_MS = 40;
const MESSAGE_REFRESH_DELAY_MS = 1000;

const state = {
  records: {},
};

export const mutations = {
  SET_LOADING(currentState, { conversationIds, clear }) {
    conversationIds.forEach(id => {
      const previous = currentState.records[id];
      currentState.records[id] = {
        state: clear ? 'unknown' : previous?.state || 'unknown',
        fetchedAt: previous?.fetchedAt || 0,
        isFetching: true,
        requestId: (previous?.requestId || 0) + 1,
      };
    });
  },
  SET_STATUS(currentState, { conversationId, status, requestId }) {
    if (currentState.records[conversationId]?.requestId !== requestId) return;

    currentState.records[conversationId] = {
      state: status,
      fetchedAt: Date.now(),
      isFetching: false,
      requestId,
    };
  },
};

export const getters = {
  getStatus: currentState => conversationId =>
    currentState.records[String(conversationId)] || { state: 'unknown' },
};

let queuedConversationIds = new Set();
let batchTimer;

const scheduleBatch = dispatch => {
  if (batchTimer) return;

  batchTimer = setTimeout(() => {
    batchTimer = null;
    const conversationIds = Array.from(queuedConversationIds).slice(
      0,
      BATCH_SIZE
    );
    conversationIds.forEach(id => queuedConversationIds.delete(id));
    if (conversationIds.length) {
      dispatch('fetchBatch', conversationIds);
    }
    if (queuedConversationIds.size) scheduleBatch(dispatch);
  }, BATCH_DELAY_MS);
};

const queueConversation = (
  { state: currentState, commit, dispatch },
  id,
  force
) => {
  const conversationId = String(id || '');
  if (!/^\d+$/.test(conversationId)) return;

  const previous = currentState.records[conversationId];
  if (!force && previous?.isFetching) return;
  if (
    !force &&
    previous?.fetchedAt &&
    Date.now() - previous.fetchedAt < STATUS_TTL_MS
  ) {
    return;
  }

  commit('SET_LOADING', { conversationIds: [conversationId], clear: force });
  queuedConversationIds.add(conversationId);
  scheduleBatch(dispatch);
};

export const actions = {
  ensure({ state: currentState, commit, dispatch }, conversationId) {
    queueConversation(
      { state: currentState, commit, dispatch },
      conversationId,
      false
    );
  },
  refresh({ state: currentState, commit, dispatch }, conversationId) {
    queueConversation(
      { state: currentState, commit, dispatch },
      conversationId,
      true
    );
  },
  async fetchBatch({ commit, state: currentState }, conversationIds) {
    const requestIds = new Map(
      conversationIds.map(id => [id, currentState.records[id]?.requestId])
    );
    try {
      const { data = {} } =
        await ConversationApi.getAiStatuses(conversationIds);
      const statuses = new Map(
        (data.statuses || []).map(item => [
          String(item.conversation_id),
          ['active', 'blocked'].includes(item.state) ? item.state : 'unknown',
        ])
      );

      conversationIds.forEach(conversationId => {
        commit('SET_STATUS', {
          conversationId,
          status: statuses.get(conversationId) || 'unknown',
          requestId: requestIds.get(conversationId),
        });
      });
    } catch (error) {
      conversationIds.forEach(conversationId => {
        commit('SET_STATUS', {
          conversationId,
          status: 'unknown',
          requestId: requestIds.get(conversationId),
        });
      });
    }
  },
};

export const conversationAiStatusPlugin = store => {
  const refreshTimers = new Map();

  store.subscribe(mutation => {
    const payload = mutation.payload;
    let conversationId;
    if (mutation.type === types.ADD_MESSAGE) {
      conversationId = payload?.conversation_id;
    } else if (
      mutation.type === types.UPDATE_CONVERSATION &&
      payload?.last_non_activity_message
    ) {
      conversationId = payload.id;
    }

    if (!conversationId) return;

    const id = String(conversationId);
    clearTimeout(refreshTimers.get(id));
    refreshTimers.set(
      id,
      setTimeout(() => {
        refreshTimers.delete(id);
        store.dispatch('conversationAiStatus/refresh', id);
      }, MESSAGE_REFRESH_DELAY_MS)
    );
  });
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
