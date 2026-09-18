import archivedMessageAlerts from '../archivedMessageAlerts';

const alert = {
  alert_id: 'archived-message:123',
  conversation_id: 42,
  inbox_id: 7,
  contact: { name: 'Cliente de teste' },
  message: 'Olá',
};

describe('archivedMessageAlerts store module', () => {
  it('accepts a valid alert only once', () => {
    const state = archivedMessageAlerts.state();
    const context = {
      commit: (type, payload) =>
        archivedMessageAlerts.mutations[type](state, payload),
      state,
    };

    expect(archivedMessageAlerts.actions.receive(context, alert)).toBe(true);
    expect(archivedMessageAlerts.actions.receive(context, alert)).toBe(false);
    expect(archivedMessageAlerts.getters.getAlerts(state)).toEqual([alert]);
  });

  it('dismisses an alert while keeping its idempotency marker', () => {
    const state = archivedMessageAlerts.state();
    archivedMessageAlerts.mutations.ADD_ALERT(state, alert);

    archivedMessageAlerts.actions.dismiss(
      {
        commit: (type, payload) =>
          archivedMessageAlerts.mutations[type](state, payload),
      },
      alert.alert_id
    );

    expect(archivedMessageAlerts.getters.getAlerts(state)).toEqual([]);
    expect(state.seenAlertIds).toEqual([alert.alert_id]);
  });
});
