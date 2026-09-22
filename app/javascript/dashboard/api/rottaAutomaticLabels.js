/* global axios */
import ApiClient from './ApiClient';

class RottaAutomaticLabelsAPI extends ApiClient {
  constructor() {
    super('rotta_automatic_labels', { accountScoped: true });
  }

  getSettings() {
    return axios.get(this.url);
  }

  updateSettings(data) {
    return axios.patch(this.url, data);
  }
}

export default new RottaAutomaticLabelsAPI();
