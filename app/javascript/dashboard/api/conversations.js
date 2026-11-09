/* global axios */
import ApiClient from './ApiClient';
import { coalescedGet } from './coalescedGet';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  mutateLabels(conversationID, { add = [], remove = [] } = {}) {
    return axios.post(`${this.url}/${conversationID}/labels`, { add, remove });
  }

  getUnreadCounts() {
    return coalescedGet(`${this.url}/unread_counts`);
  }

  getAiStatuses(conversationIds) {
    return axios.post(`${this.url}/ai_status`, {
      conversation_ids: conversationIds,
    });
  }
}

export default new ConversationApi();
