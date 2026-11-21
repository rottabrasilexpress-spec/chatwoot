/* global axios */
import ApiClient from './ApiClient';
import { coalescedGet } from './coalescedGet';

class RottaPickupsAPI extends ApiClient {
  constructor() {
    super('rotta_pickups', { accountScoped: true });
  }

  page(page, sortBy) {
    const query = new URLSearchParams({ page, sort_by: sortBy });
    return coalescedGet(this.url + '?' + query.toString());
  }

  reminders() {
    return coalescedGet(this.url + '/reminders?include_delivery=true');
  }

  acknowledge(day, items) {
    const dates = items.map(
      ({ id, starts_on, ends_on, reminder_kind, reminder_on }) => ({
        id,
        starts_on,
        ends_on,
        reminder_kind,
        reminder_on,
      })
    );
    return axios.post(this.url + '/acknowledge', { day, items: dates });
  }

  complete(id, { starts_on, ends_on, delivery_on }) {
    return axios.post(this.url + '/' + id + '/complete', {
      starts_on,
      ends_on,
      delivery_on,
    });
  }
}

export default new RottaPickupsAPI();
