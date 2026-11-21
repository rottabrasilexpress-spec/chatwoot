import { shallowRef } from 'vue';
import api from 'dashboard/api/rottaPickups';

export const pickupRequest = shallowRef(null);
export const pickupRevision = shallowRef(0);

export const announcePickupChange = () => {
  pickupRevision.value += 1;
};

export const confirmPickupDate = (conversationId, save, mode = 'schedule') => {
  const active = pickupRequest.value;
  if (active) {
    if (active.conversationId === conversationId && active.mode === mode)
      return active.promise;
    return Promise.resolve({ status: 'cancelled' });
  }

  let finish;
  const promise = new Promise(resolve => {
    finish = resolve;
  });
  pickupRequest.value = { conversationId, save, finish, promise, mode };
  return promise;
};

export const editPickupDates = (
  conversationId,
  store,
  { confirmWindow = false, focusDelivery = false } = {}
) => {
  let mode = 'edit';
  if (focusDelivery) mode = 'delivery';
  if (confirmWindow) mode = 'confirm';
  return confirmPickupDate(
    conversationId,
    async (pickup, expected) => {
      const { data } = await api.update(conversationId, {
        pickup,
        expected,
        confirm_window: confirmWindow,
      });
      store.commit('SET_ROTTA_PICKUP', {
        id: conversationId,
        rotta_pickup: data.rotta_pickup,
      });
      await store.dispatch('contacts/updateContact', data.contact);
      announcePickupChange();
      return { status: 'success' };
    },
    mode
  );
};

export const finishPickupDialog = result => {
  const request = pickupRequest.value;
  pickupRequest.value = null;
  request?.finish(result);
};
