/* global axios */
import ApiClient from '../ApiClient';

class ConversationAiAPI extends ApiClient {
  constructor() {
    super('captain/conversation_ai', { accountScoped: true });
  }

  profile(conversationId, { routeOnly = false } = {}) {
    return axios.post(`${this.url}/profile`, {
      conversation_id: conversationId,
      ...(routeOnly ? { route_only: true } : {}),
    });
  }
}

export default new ConversationAiAPI();
