import axios from 'axios';
import conversationLabels, {
  actions,
  mutations,
} from '../../conversationLabels';

global.axios = axios;
vi.mock('axios');

describe('conversation label read/write races', () => {
  let context;
  let conversation;

  beforeEach(() => {
    axios.get.mockReset();
    axios.post.mockReset();
    conversationLabels.state.records = {};
    conversation = { id: 9701, labels: ['kelvin'] };
    context = {
      commit: (type, payload) =>
        mutations[type](conversationLabels.state, payload),
      dispatch: vi.fn((action, payload) => {
        if (action === 'updateConversation') conversation = payload;
      }),
      rootGetters: { getConversationById: () => conversation },
    };
  });

  it('does not restore KELVIN when an earlier GET finishes after a saved replacement', async () => {
    const stale = Promise.withResolvers();
    axios.get.mockReturnValueOnce(stale.promise);
    axios.post.mockResolvedValue({ data: { payload: ['orcamento-feito'] } });

    const read = actions.get(context, 9701);
    await vi.waitFor(() => expect(axios.get).toHaveBeenCalledTimes(1));
    await actions.update(context, {
      conversationId: 9701,
      labels: ['orcamento-feito'],
    });
    stale.resolve({ data: { payload: ['kelvin'] } });
    await read;

    expect(conversationLabels.state.records[9701]).toEqual(['orcamento-feito']);
    expect(conversation.labels).toEqual(['orcamento-feito']);
  });

  it('waits for an already pending write before fetching saved labels', async () => {
    const write = Promise.withResolvers();
    axios.post.mockReturnValueOnce(write.promise);
    axios.get.mockResolvedValue({ data: { payload: ['orcamento-feito'] } });

    const update = actions.update(context, {
      conversationId: 9701,
      labels: ['orcamento-feito'],
    });
    await vi.waitFor(() => expect(axios.post).toHaveBeenCalledTimes(1));
    const read = actions.get(context, 9701);
    await Promise.resolve();
    const earlyReads = axios.get.mock.calls.length;
    write.resolve({ data: { payload: ['orcamento-feito'] } });
    await Promise.all([update, read]);

    expect(earlyReads).toBe(0);
    expect(axios.get).toHaveBeenCalledTimes(1);
    expect(conversation.labels).toEqual(['orcamento-feito']);
  });

  it('keeps the latest read when two GET responses arrive in reverse order', async () => {
    const stale = Promise.withResolvers();
    axios.get
      .mockReturnValueOnce(stale.promise)
      .mockResolvedValueOnce({ data: { payload: ['orcamento-feito'] } });
    const first = actions.get(context, 9701);
    await vi.waitFor(() => expect(axios.get).toHaveBeenCalledTimes(1));
    await actions.get(context, 9701);
    stale.resolve({ data: { payload: ['kelvin'] } });
    await first;

    expect(conversation.labels).toEqual(['orcamento-feito']);
  });

  it.each([
    ['update', false],
    ['update', true],
    ['mutate', false],
    ['mutate', true],
  ])(
    'does not let a failed %s recovery overwrite a newer change (GET rejects: %s)',
    async (action, rejects) => {
      const recovery = Promise.withResolvers();
      if (action === 'mutate') {
        axios.get.mockResolvedValueOnce({ data: { payload: ['kelvin'] } });
      }
      axios.get.mockReturnValueOnce(recovery.promise);
      axios.post
        .mockRejectedValueOnce(new Error('temporary failure'))
        .mockResolvedValueOnce({ data: { payload: ['orcamento-feito'] } });

      const failed = actions[action](context, {
        conversationId: 9701,
        labels: ['kelvin', 'emitir-contrato'],
        add: ['emitir-contrato'],
      });
      await vi.waitFor(() =>
        expect(axios.get).toHaveBeenCalledTimes(action === 'mutate' ? 2 : 1)
      );
      await actions.update(context, {
        conversationId: 9701,
        labels: ['orcamento-feito'],
      });
      if (rejects) recovery.reject(new Error('read also failed'));
      else recovery.resolve({ data: { payload: ['kelvin'] } });
      await expect(failed).resolves.toMatchObject({ status: 'superseded' });

      expect(conversation.labels).toEqual(['orcamento-feito']);
      expect(conversationLabels.state.uiFlags.isError).toBe(false);
    }
  );

  it('does not hold up an unrelated conversation while another write is pending', async () => {
    const write = Promise.withResolvers();
    axios.post.mockReturnValueOnce(write.promise);
    axios.get.mockResolvedValue({ data: { payload: ['caio-atencao'] } });
    const update = actions.update(context, {
      conversationId: 9701,
      labels: ['orcamento-feito'],
    });
    await actions.get(context, 9702);
    write.resolve({ data: { payload: ['orcamento-feito'] } });
    await update;

    expect(conversationLabels.state.records[9702]).toEqual(['caio-atencao']);
    expect(conversationLabels.state.records[9701]).toEqual(['orcamento-feito']);
  });

  it('still accepts a saved label change made externally after the local write', async () => {
    axios.post.mockResolvedValue({ data: { payload: ['orcamento-feito'] } });
    await actions.update(context, {
      conversationId: 9701,
      labels: ['orcamento-feito'],
    });
    axios.get.mockResolvedValue({
      data: { payload: ['orcamento-feito', 'caio-atencao'] },
    });
    await actions.get(context, 9701);

    expect(conversation.labels).toEqual(['orcamento-feito', 'caio-atencao']);
  });
});
