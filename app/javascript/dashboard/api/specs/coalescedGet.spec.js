/* global axios */
import { coalescedGet } from '../coalescedGet';

describe('concurrent sidebar reads', () => {
  beforeEach(() => vi.stubGlobal('axios', { get: vi.fn() }));
  afterEach(() => vi.unstubAllGlobals());

  it('starts a fresh read after the previous response completes', async () => {
    axios.get.mockResolvedValue({ data: {} });
    await coalescedGet('/api/v1/accounts/1/labels');
    await coalescedGet('/api/v1/accounts/1/labels');
    expect(axios.get).toHaveBeenCalledTimes(2);
  });

  it('keeps accounts and different counters separate', async () => {
    let resolve;
    const pending = new Promise(done => {
      resolve = done;
    });
    axios.get.mockReturnValue(pending);
    const first = coalescedGet('/api/v1/accounts/1/labels');
    const same = coalescedGet('/api/v1/accounts/1/labels');
    const other = coalescedGet('/api/v1/accounts/2/labels');
    const unread = coalescedGet(
      '/api/v1/accounts/1/conversations/unread_counts'
    );
    expect(first).toBe(same);
    expect(axios.get).toHaveBeenCalledTimes(3);
    resolve({ data: {} });
    await Promise.all([first, same, other, unread]);
  });

  it('allows recovery after a failed request', async () => {
    axios.get
      .mockRejectedValueOnce(new Error('offline'))
      .mockResolvedValueOnce({ data: {} });
    await expect(coalescedGet('/api/v1/accounts/1/labels')).rejects.toThrow(
      'offline'
    );
    await expect(coalescedGet('/api/v1/accounts/1/labels')).resolves.toEqual({
      data: {},
    });
    expect(axios.get).toHaveBeenCalledTimes(2);
  });
});
