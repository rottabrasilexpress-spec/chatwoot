import { useLocalStorage } from '@vueuse/core';

export const usePickupSort = () =>
  useLocalStorage('rotta-pickup-sort-order', 'pickup_asc');
