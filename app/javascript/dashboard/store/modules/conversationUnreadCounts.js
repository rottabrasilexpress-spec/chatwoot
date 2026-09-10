import ConversationAPI from '../../api/conversations';
import ConversationMetaAPI from '../../api/inbox/conversation';
import types from '../mutation-types';

export const state = {
  allCount: 0,
  archivedCount: 0,
  inboxes: {},
  labels: {},
  teams: {},
  mentionsCount: 0,
  participatingCount: 0,
  unattendedCount: 0,
  folders: {},
};

const normalizeCount = count => {
  const parsedCount = Number(count);
  return Number.isFinite(parsedCount) && parsedCount > 0 ? parsedCount : 0;
};

const normalizeCounts = counts => {
  return Object.entries(counts || {}).reduce((result, [id, count]) => {
    const parsedCount = normalizeCount(count);
    if (parsedCount > 0) {
      result[String(id)] = parsedCount;
    }

    return result;
  }, {});
};

export const getters = {
  getAllUnreadCount($state) {
    return $state.allCount;
  },
  getArchivedUnreadCount($state) {
    return $state.archivedCount;
  },
  getInboxUnreadCount: $state => inboxId => {
    return $state.inboxes[String(inboxId)] || 0;
  },
  getLabelUnreadCount: $state => labelId => {
    return $state.labels[String(labelId)] || 0;
  },
  getTeamUnreadCount: $state => teamId => {
    return $state.teams[String(teamId)] || 0;
  },
  getMentionsUnreadCount($state) {
    return $state.mentionsCount;
  },
  getParticipatingUnreadCount($state) {
    return $state.participatingCount;
  },
  getUnattendedUnreadCount($state) {
    return $state.unattendedCount;
  },
  getFolderUnreadCount: $state => folderId => {
    return $state.folders[String(folderId)] || 0;
  },
  getInboxUnreadCounts($state) {
    return $state.inboxes;
  },
  getLabelUnreadCounts($state) {
    return $state.labels;
  },
  getTeamUnreadCounts($state) {
    return $state.teams;
  },
  getFolderUnreadCounts($state) {
    return $state.folders;
  },
};

export const actions = {
  get: async function getUnreadCounts({ commit }) {
    try {
      const response = await ConversationAPI.getUnreadCounts();
      commit(types.SET_CONVERSATION_UNREAD_COUNTS, response.data.payload);
    } catch (error) {
      if (error?.response?.status !== 403) return;

      try {
        const response = await ConversationMetaAPI.meta({
          assigneeType: 'all',
          status: 'all',
          conversationType: 'unread',
        });
        commit(
          types.SET_ALL_CONVERSATION_UNREAD_COUNT,
          response.data?.meta?.all_count
        );
      } catch (_fallbackError) {
        // Ignore fallback errors so the sidebar can continue rendering.
      }
    }
  },
  clear({ commit }) {
    commit(types.SET_CONVERSATION_UNREAD_COUNTS, {});
  },
};

export const mutations = {
  [types.SET_ALL_CONVERSATION_UNREAD_COUNT]($state, count) {
    $state.allCount = normalizeCount(count);
  },

  [types.SET_CONVERSATION_UNREAD_COUNTS]($state, payload = {}) {
    $state.allCount = normalizeCount(payload.all_count);
    $state.archivedCount = normalizeCount(payload.archived_count);
    $state.inboxes = normalizeCounts(payload.inboxes);
    $state.labels = normalizeCounts(payload.labels);
    $state.teams = normalizeCounts(payload.teams);
    $state.mentionsCount = normalizeCount(payload.mentions_count);
    $state.participatingCount = normalizeCount(payload.participating_count);
    $state.unattendedCount = normalizeCount(payload.unattended_count);
    $state.folders = normalizeCounts(payload.folders);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
