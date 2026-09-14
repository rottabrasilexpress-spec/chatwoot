/* global axios */
import ApiClient from '../ApiClient';

class ConversationAiAPI extends ApiClient {
  constructor() {
    super('captain/conversation_ai', { accountScoped: true });
  }

  profile(conversationId) {
    return axios.post(`${this.url}/profile`, {
      conversation_id: conversationId,
    });
  }
}

export default new ConversationAiAPI();
