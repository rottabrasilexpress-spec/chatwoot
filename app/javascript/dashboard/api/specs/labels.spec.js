import labels from '../labels';
import ApiClient from '../ApiClient';
import axios from 'axios';

describe('#LabelsAPI', () => {
  beforeEach(() => vi.stubGlobal('axios', axios));
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });
  it('creates correct instance', () => {
    expect(labels).toBeInstanceOf(ApiClient);
    expect(labels).toHaveProperty('get');
    expect(labels).toHaveProperty('show');
    expect(labels).toHaveProperty('create');
    expect(labels).toHaveProperty('update');
    expect(labels).toHaveProperty('delete');
    expect(labels.url).toBe('/api/v1/labels');
  });

  it('shares simultaneous catalog and sidebar reads for the same account', async () => {
    let resolve;
    const response = { data: { payload: [] } };
    const pending = new Promise(done => {
      resolve = done;
    });
    const get = vi.spyOn(axios, 'get').mockReturnValue(pending);
    const requests = Array.from({ length: 20 }, () => labels.get(false));
    const requestCount = get.mock.calls.length;
    resolve(response);
    await Promise.all(requests);
    expect(requestCount).toBe(1);
    get.mockRestore();
  });
});
