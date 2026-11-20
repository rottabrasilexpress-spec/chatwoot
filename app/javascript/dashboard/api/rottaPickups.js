/* global axios */
import ApiClient from './ApiClient';
import { coalescedGet } from './coalescedGet';

class RottaPickupsAPI extends ApiClient {
  constructor() {
    super('rotta_pickups', { accountScoped: true });
  }

  page(page) {
    return coalescedGet(this.url + '?page=' + page);
  }

  reminders() {
    return coalescedGet(this.url + '/reminders');
  }

  acknowledge(day, items) {
    const dates = items.map(({ id, starts_on, ends_on }) => ({
      id,
      starts_on,
      ends_on,
    }));
    return axios.post(this.url + '/acknowledge', { day, items: dates });
  }

  complete(id, { starts_on, ends_on }) {
    return axios.post(this.url + '/' + id + '/complete', {
      starts_on,
      ends_on,
    });
  }
}

export default new RottaPickupsAPI();
