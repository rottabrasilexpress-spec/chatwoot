import { describe, expect, it } from 'vitest';
import { actions, getters, mutations } from '../caioAttentionAlerts';

const alert = {
  alert_id: 'alert-1',
  conversation_id: 42,
  inbox_id: 7,
  label: 'caio-atencao',
};

describe('caioAttentionAlerts store module', () => {
  it('queues valid alerts and ignores the same alert id twice', () => {
    const state = { alerts: [], seenAlertIds: [] };
    const commit = (type, payload) => mutations[type](state, payload);

    expect(actions.receive({ commit, state }, alert)).toBe(true);
    expect(actions.receive({ commit, state }, alert)).toBe(false);
    expect(getters.getAlerts(state)).toEqual([alert]);
  });

  it('rejects malformed or unrelated events', () => {
    const state = { alerts: [], seenAlertIds: [] };
    const commit = (type, payload) => mutations[type](state, payload);

    expect(
      actions.receive({ commit, state }, { ...alert, label: 'kelvin' })
    ).toBe(false);
    expect(getters.getAlerts(state)).toEqual([]);
  });

  it('accepts a private requester alert without a Caio Atenção label', () => {
    const state = { alerts: [], seenAlertIds: [] };
    const commit = (type, payload) => mutations[type](state, payload);
    const requesterAlert = {
      alert_id: 'request-1',
      conversation_id: 43,
      inbox_id: 7,
      kind: 'attention-requested',
    };

    expect(actions.receive({ commit, state }, requesterAlert)).toBe(true);
    expect(getters.getAlerts(state)).toEqual([requesterAlert]);
  });

  it('dismisses an alert without removing its deduplication record', () => {
    const state = { alerts: [], seenAlertIds: [] };
    const commit = (type, payload) => mutations[type](state, payload);

    actions.receive({ commit, state }, alert);
    actions.dismiss({ commit }, alert.alert_id);

    expect(getters.getAlerts(state)).toEqual([]);
    expect(actions.receive({ commit, state }, alert)).toBe(false);
  });
});
