import * as types from '../mutation-types';
import ConversationAPI from '../../api/conversations';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import {
  beginConversationLabelMutation,
  isLatestConversationLabelMutation,
  withConversationLabelMutationLock,
} from 'dashboard/helper/conversationLabelMutationQueue';

let pendingLabelUpdates = 0;

const labelTitles = value => {
  let labels = [];
  if (Array.isArray(value)) {
    labels = value;
  } else if (Array.isArray(value?.labels)) {
    labels = value.labels;
  }
  return labels
    .map(label => (typeof label === 'string' ? label : label?.title))
    .filter(Boolean);
};

const updateRootConversationLabels = (dispatch, rootGetters, id, value) => {
  const conversation = rootGetters?.getConversationById?.(Number(id));
  if (!conversation) return;
  dispatch(
    'updateConversation',
    { ...conversation, labels: labelTitles(value) },
    { root: true }
  );
};

const state = {
  records: {},
  uiFlags: {
    isFetching: false,
    isUpdating: false,
    isError: false,
  },
};

export const getters = {
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getConversationLabels: $state => id => {
    return $state.records[Number(id)] || [];
  },
  hasConversationLabels: $state => id =>
    Object.prototype.hasOwnProperty.call($state.records, Number(id)),
};

export const actions = {
  get: async ({ commit, dispatch, rootGetters }, conversationId) => {
    commit(types.default.SET_CONVERSATION_LABELS_UI_FLAG, {
      isFetching: true,
    });
    try {
      const response = await ConversationAPI.getLabels(conversationId);
      commit(types.default.SET_CONVERSATION_LABELS, {
        id: conversationId,
        data: response.data.payload,
      });
      updateRootConversationLabels(
        dispatch,
        rootGetters,
        conversationId,
        response.data.payload
      );
      commit(types.default.SET_CONVERSATION_LABELS_UI_FLAG, {
        isFetching: false,
      });
    } catch (error) {
      commit(types.default.SET_CONVERSATION_LABELS_UI_FLAG, {
        isFetching: false,
      });
    }
  },
  update: async (
    { commit, dispatch, rootGetters },
    { conversationId, labels }
  ) => {
    const version = beginConversationLabelMutation([conversationId]);
    const previousLabels =
      state.records[Number(conversationId)] ||
      rootGetters?.getConversationById?.(Number(conversationId))?.labels ||
      [];
    pendingLabelUpdates += 1;
    commit(types.default.SET_CONVERSATION_LABELS_UI_FLAG, {
      isUpdating: true,
    });
    commit(types.default.SET_CONVERSATION_LABELS, {
      id: conversationId,
      data: labels,
    });
    updateRootConversationLabels(dispatch, rootGetters, conversationId, labels);
    try {
      const response = await withConversationLabelMutationLock(
        [conversationId],
        () => ConversationAPI.updateLabels(conversationId, labels)
      );
      if (isLatestConversationLabelMutation(conversationId, version)) {
        commit(types.default.SET_CONVERSATION_LABELS, {
          id: conversationId,
          data: response.data.payload,
        });
        updateRootConversationLabels(
          dispatch,
          rootGetters,
          conversationId,
          response.data.payload
        );
        commit(types.default.SET_CONVERSATION_LABELS_UI_FLAG, {
          isError: false,
        });
        emitter.emit(BUS_EVENTS.ROTTA_FOLLOW_UP_REFRESH, {
          conversation_id: conversationId,
          labels: response.data.payload,
        });
      }
      return true;
    } catch (error) {
      if (isLatestConversationLabelMutation(conversationId, version)) {
        try {
          const response = await ConversationAPI.getLabels(conversationId);
          commit(types.default.SET_CONVERSATION_LABELS, {
            id: conversationId,
            data: response.data.payload,
          });
          updateRootConversationLabels(
            dispatch,
            rootGetters,
            conversationId,
            response.data.payload
          );
        } catch {
          commit(types.default.SET_CONVERSATION_LABELS, {
            id: conversationId,
            data: previousLabels || [],
          });
          updateRootConversationLabels(
            dispatch,
            rootGetters,
            conversationId,
            previousLabels || []
          );
        }
        commit(types.default.SET_CONVERSATION_LABELS_UI_FLAG, {
          isError: true,
        });
      }
      return false;
    } finally {
      pendingLabelUpdates -= 1;
      commit(types.default.SET_CONVERSATION_LABELS_UI_FLAG, {
        isUpdating: pendingLabelUpdates > 0,
      });
    }
  },
  setBulkConversationLabels({ commit }, conversations) {
    commit(types.default.SET_BULK_CONVERSATION_LABELS, conversations);
  },
  setConversationLabel({ commit }, { id, data }) {
    commit(types.default.SET_CONVERSATION_LABELS, { id, data });
  },
};

export const mutations = {
  [types.default.SET_CONVERSATION_LABELS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.default.SET_CONVERSATION_LABELS]: ($state, { id, data }) => {
    $state.records = { ...$state.records, [id]: data };
  },
  [types.default.SET_BULK_CONVERSATION_LABELS]: ($state, conversations) => {
    const updatedRecords = { ...$state.records };
    conversations.forEach(conversation => {
      updatedRecords[conversation.id] = conversation.labels;
    });

    $state.records = updatedRecords;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
