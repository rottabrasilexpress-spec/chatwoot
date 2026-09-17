/* global axios */
import ApiClient from './ApiClient';

class GlobalAiAPI extends ApiClient {
  constructor() {
    super('global_ai', { accountScoped: true });
  }

  getAccess() {
    return axios.get(`${this.url}/access`);
  }

  updateAccess(userIds) {
    return axios.patch(`${this.url}/access`, { user_ids: userIds });
  }

  listThreads() {
    return axios.get(`${this.url}/threads`);
  }

  createThread(message) {
    return axios.post(`${this.url}/threads`, { message });
  }

  getThread(threadId) {
    return axios.get(`${this.url}/threads/${threadId}`);
  }

  createMessage(threadId, message) {
    return axios.post(`${this.url}/threads/${threadId}/messages`, { message });
  }

  executeAction(payload) {
    return axios.post(`${this.url}/actions`, payload);
  }
}

export default new GlobalAiAPI();
