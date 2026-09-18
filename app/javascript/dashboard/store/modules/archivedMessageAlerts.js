const MAX_SEEN_ALERTS = 500;

const isValidAlert = alert =>
  Boolean(alert?.alert_id && alert.conversation_id && alert.inbox_id);

const state = () => ({
  alerts: [],
  seenAlertIds: [],
});

export const getters = {
  getAlerts: $state => $state.alerts,
  hasAlerts: $state => $state.alerts.length > 0,
};

export const actions = {
  receive({ commit, state: $state }, alert) {
    if (!isValidAlert(alert) || $state.seenAlertIds.includes(alert.alert_id)) {
      return false;
    }

    commit('ADD_ALERT', alert);
    return true;
  },

  dismiss({ commit }, alertId) {
    commit('DISMISS_ALERT', alertId);
  },
};

export const mutations = {
  ADD_ALERT($state, alert) {
    if ($state.seenAlertIds.includes(alert.alert_id)) return false;

    $state.seenAlertIds = [...$state.seenAlertIds, alert.alert_id].slice(
      -MAX_SEEN_ALERTS
    );
    $state.alerts = [...$state.alerts, alert];
    return true;
  },

  DISMISS_ALERT($state, alertId) {
    $state.alerts = $state.alerts.filter(alert => alert.alert_id !== alertId);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
