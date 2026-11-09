import CacheEnabledApiClient from './CacheEnabledApiClient';
import { coalescedGet } from './coalescedGet';

class LabelsAPI extends CacheEnabledApiClient {
  constructor() {
    super('labels', { accountScoped: true });
  }

  getFromNetwork() {
    return coalescedGet(this.url);
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'label';
  }
}

export default new LabelsAPI();
