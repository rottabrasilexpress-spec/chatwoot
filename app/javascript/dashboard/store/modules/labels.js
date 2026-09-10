import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import LabelsAPI from '../../api/labels';
import AnalyticsHelper from '../../helper/AnalyticsHelper';
import { LABEL_EVENTS } from '../../helper/AnalyticsHelper/events';

export const SIDEBAR_LABEL_COUNTS_MUTATION = 'SET_SIDEBAR_LABEL_COUNTS';

const SIDEBAR_LABEL_COLOR = Object.freeze({
  budget: '#f59e0b',
  caioAttention: '#1e3a8a',
  closedClients: '#16a34a',
});

export const normalizeSidebarLabel = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');

export const SIDEBAR_LABEL_DEFINITIONS = Object.freeze([
  Object.freeze({
    key: 'budget',
    fallbackTitle: 'kelvin',
    aliases: Object.freeze(['kelvin', 'kelvin-caio']),
    color: SIDEBAR_LABEL_COLOR.budget,
  }),
  Object.freeze({
    key: 'caioAttention',
    fallbackTitle: 'caio-atencao',
    aliases: Object.freeze(['caio-atencao']),
    color: SIDEBAR_LABEL_COLOR.caioAttention,
  }),
  Object.freeze({
    key: 'closedClients',
    fallbackTitle: 'clientes-fechados',
    aliases: Object.freeze(['clientes-fechados']),
    color: SIDEBAR_LABEL_COLOR.closedClients,
  }),
]);

export const findSidebarLabel = (records, definition) => {
  const aliases = definition?.aliases || [];
  const normalizedAliases = aliases.map(normalizeSidebarLabel);

  return (Array.isArray(records) ? records : []).find(record =>
    normalizedAliases.includes(normalizeSidebarLabel(record.title))
  );
};

const normalizeCount = value => {
  const count = Number(value);
  return Number.isFinite(count) && count > 0 ? count : 0;
};

let sidebarCountsRequestId = 0;

export const state = {
  records: [],
  sidebarLabelCounts: {},
  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isDeleting: false,
  },
};

export const getters = {
  getLabels(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
  getLabelsOnSidebar(_state) {
    return _state.records
      .filter(record => record.show_on_sidebar)
      .sort((a, b) => a.title.localeCompare(b.title));
  },
  getLabelById: _state => id => {
    return _state.records.find(record => record.id === Number(id)) || {};
  },
  getSidebarLabelCount: _state => key => {
    const definition = SIDEBAR_LABEL_DEFINITIONS.find(item => item.key === key);
    if (definition && !findSidebarLabel(_state.records, definition)) return 0;

    return normalizeCount(_state.sidebarLabelCounts?.[key]);
  },
  getSidebarLabelCounts(_state) {
    return _state.sidebarLabelCounts;
  },
};

export const actions = {
  revalidate: async function revalidate({ commit }, { newKey }) {
    try {
      const isExistingKeyValid = await LabelsAPI.validateCacheKey(newKey);
      if (!isExistingKeyValid) {
        const response = await LabelsAPI.refetchAndCommit(newKey);
        commit(types.SET_LABELS, response.data.payload);
      }
    } catch (error) {
      // Ignore error
    }
  },

  get: async function getLabels({ commit }, { forceNetwork = false } = {}) {
    commit(types.SET_LABEL_UI_FLAG, { isFetching: true });
    try {
      const response = await LabelsAPI.get(!forceNetwork);
      const sortedLabels = response.data.payload.sort((a, b) =>
        a.title.localeCompare(b.title)
      );
      commit(types.SET_LABELS, sortedLabels);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isFetching: false });
    }
  },

  getSidebarCounts: async function getSidebarCounts({
    state: moduleState,
    commit,
  }) {
    sidebarCountsRequestId += 1;
    const requestId = sidebarCountsRequestId;
    if (requestId !== sidebarCountsRequestId) return;

    const counts = Object.fromEntries(
      SIDEBAR_LABEL_DEFINITIONS.map(definition => [
        definition.key,
        normalizeCount(
          findSidebarLabel(moduleState.records, definition)?.contacts_count
        ),
      ])
    );
    commit(SIDEBAR_LABEL_COUNTS_MUTATION, counts);
  },

  create: async function createLabels({ commit }, cannedObj) {
    commit(types.SET_LABEL_UI_FLAG, { isCreating: true });
    try {
      const response = await LabelsAPI.create(cannedObj);
      AnalyticsHelper.track(LABEL_EVENTS.CREATE);
      commit(types.ADD_LABEL, response.data);
    } catch (error) {
      const errorMessage = error?.response?.data?.message;
      throw new Error(errorMessage);
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateLabels({ commit }, { id, ...updateObj }) {
    commit(types.SET_LABEL_UI_FLAG, { isUpdating: true });
    try {
      const response = await LabelsAPI.update(id, updateObj);
      AnalyticsHelper.track(LABEL_EVENTS.UPDATE);
      commit(types.EDIT_LABEL, response.data);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteLabels({ commit }, id) {
    commit(types.SET_LABEL_UI_FLAG, { isDeleting: true });
    try {
      await LabelsAPI.delete(id);
      AnalyticsHelper.track(LABEL_EVENTS.DELETED);
      commit(types.DELETE_LABEL, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_LABEL_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_LABEL_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.SET_LABELS]: MutationHelpers.set,
  [types.ADD_LABEL]: MutationHelpers.create,
  [types.EDIT_LABEL]: MutationHelpers.update,
  [types.DELETE_LABEL]: MutationHelpers.destroy,
  [SIDEBAR_LABEL_COUNTS_MUTATION](_state, counts) {
    _state.sidebarLabelCounts = counts;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
