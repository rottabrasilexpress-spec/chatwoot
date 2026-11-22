/* global axios */
import ApiClient from '../ApiClient';

class CopilotMessages extends ApiClient {
  constructor() {
    super('captain/copilot_threads', { accountScoped: true });
  }

  get(threadId, { afterId, beforeId } = {}) {
    const params = {};
    if (afterId) params.after_id = afterId;
    if (beforeId) params.before_id = beforeId;
    return axios.get(`${this.url}/${threadId}/copilot_messages`, {
      params: afterId || beforeId ? params : undefined,
      timeout: 10000,
    });
  }

  create({ threadId, ...rest }) {
    return axios.post(`${this.url}/${threadId}/copilot_messages`, rest);
  }
}

export default new CopilotMessages();
