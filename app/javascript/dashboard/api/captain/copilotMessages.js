/* global axios */
import ApiClient from '../ApiClient';

class CopilotMessages extends ApiClient {
  constructor() {
    super('captain/copilot_threads', { accountScoped: true });
  }

  get(threadId, { afterId } = {}) {
    return axios.get(`${this.url}/${threadId}/copilot_messages`, {
      params: afterId ? { after_id: afterId } : undefined,
      timeout: 10000,
    });
  }

  create({ threadId, ...rest }) {
    return axios.post(`${this.url}/${threadId}/copilot_messages`, rest);
  }
}

export default new CopilotMessages();
