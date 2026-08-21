import { LocalStorage } from 'shared/helpers/localStorage';
import {
  DEFAULT_SIDEBAR_SORT_PREFERENCES,
  SIDEBAR_SORT_KEYS,
  isValidSidebarSort,
  normalizeSidebarSortPreferences,
} from 'dashboard/helper/sidebarSort';

const STORAGE_NAME = 'chatwoot_sidebar_sort_preferences';
const ROTTA_LABEL_ORDER_MIGRATION_STORAGE =
  'chatwoot_rotta_label_order_migration';
export const SET_SIDEBAR_SORT_PREFERENCES = 'SET_SIDEBAR_SORT_PREFERENCES';

const getPreferenceScope = rootGetters => {
  const currentUserId = rootGetters.getCurrentUserID;
  const currentAccountId = rootGetters.getCurrentAccountId;

  if (!currentUserId || !currentAccountId) return null;

  return `${currentUserId}:${currentAccountId}`;
};

export const state = {
  preferences: { ...DEFAULT_SIDEBAR_SORT_PREFERENCES },
  storageKey: null,
};

export const getters = {
  getSectionSort: $state => section => {
    return (
      $state.preferences[section] || DEFAULT_SIDEBAR_SORT_PREFERENCES[section]
    );
  },
};

export const actions = {
  initialize({ commit, rootGetters }) {
    const storageKey = getPreferenceScope(rootGetters);
    const storedPreferences = storageKey
      ? LocalStorage.getFromJsonStore(STORAGE_NAME, storageKey)
      : {};

    const preferences = normalizeSidebarSortPreferences(storedPreferences);
    const hasRottaLabelOrderMigration = storageKey
      ? LocalStorage.getFromJsonStore(
          ROTTA_LABEL_ORDER_MIGRATION_STORAGE,
          storageKey
        )
      : true;

    if (!hasRottaLabelOrderMigration) {
      preferences.labels = SIDEBAR_SORT_KEYS.ROTTA_TRAIL;
      LocalStorage.updateJsonStore(
        ROTTA_LABEL_ORDER_MIGRATION_STORAGE,
        storageKey,
        true
      );
    }

    commit(SET_SIDEBAR_SORT_PREFERENCES, {
      preferences,
      storageKey,
    });
  },
  setSectionSort({ commit, rootGetters, state: currentState }, payload = {}) {
    const { section, sortBy } = payload;

    if (!isValidSidebarSort(section, sortBy)) return;

    const storageKey =
      currentState.storageKey || getPreferenceScope(rootGetters);
    const preferences = {
      ...currentState.preferences,
      [section]: sortBy,
    };

    commit(SET_SIDEBAR_SORT_PREFERENCES, {
      preferences,
      storageKey,
    });

    if (storageKey) {
      LocalStorage.updateJsonStore(STORAGE_NAME, storageKey, preferences);
    }
  },
};

export const mutations = {
  [SET_SIDEBAR_SORT_PREFERENCES]($state, payload = {}) {
    const { preferences = {}, storageKey = null } = payload;
    $state.preferences = normalizeSidebarSortPreferences(preferences);
    $state.storageKey = storageKey;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
