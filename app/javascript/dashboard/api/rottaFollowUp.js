import ApiClient from './ApiClient';

class RottaFollowUpAPI extends ApiClient {
  constructor() {
    super('rotta_follow_up', { accountScoped: true });
  }
}

export default new RottaFollowUpAPI();
