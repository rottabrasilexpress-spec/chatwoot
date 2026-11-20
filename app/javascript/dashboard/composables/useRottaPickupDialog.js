import { shallowRef } from 'vue';

export const pickupRequest = shallowRef(null);
export const pickupRevision = shallowRef(0);

export const announcePickupChange = () => {
  pickupRevision.value += 1;
};

export const confirmPickupDate = (conversationId, save) => {
  const active = pickupRequest.value;
  if (active) {
    if (active.conversationId === conversationId) return active.promise;
    return Promise.resolve({ status: 'cancelled' });
  }

  let finish;
  const promise = new Promise(resolve => {
    finish = resolve;
  });
  pickupRequest.value = { conversationId, save, finish, promise };
  return promise;
};

export const finishPickupDialog = result => {
  const request = pickupRequest.value;
  pickupRequest.value = null;
  request?.finish(result);
};
