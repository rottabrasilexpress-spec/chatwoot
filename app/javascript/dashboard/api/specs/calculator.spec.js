import CalculatorAPI from '../calculator';

describe('CalculatorAPI', () => {
  const originalAxios = window.axios;
  const axiosMock = {
    post: vi.fn(() => Promise.resolve({ data: { ok: true } })),
  };

  beforeEach(() => {
    window.axios = axiosMock;
  });

  afterEach(() => {
    window.axios = originalAxios;
    vi.clearAllMocks();
  });

  it('posts a calculator payload to the account-scoped endpoint', async () => {
    const payload = { freight: { origin: 'São Paulo - SP' } };

    await CalculatorAPI.calculate(1, payload);

    expect(axiosMock.post).toHaveBeenCalledWith(
      '/api/v1/accounts/1/calculator/calculate',
      { calculator: payload }
    );
  });
});
