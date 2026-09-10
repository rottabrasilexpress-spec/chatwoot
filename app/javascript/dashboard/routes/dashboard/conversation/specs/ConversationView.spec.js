import ConversationView from '../ConversationView.vue';

describe('ConversationView deep-linked conversation loading', () => {
  it('requests a deep-linked conversation before list initialization finishes', () => {
    const fetchConversationIfUnavailable = vi.fn();
    const initialize = vi.fn();
    const watch = vi.fn();
    const calls = [];
    const dispatch = vi.fn(action => calls.push(`dispatch:${action}`));

    fetchConversationIfUnavailable.mockImplementation(() =>
      calls.push('fetch-conversation')
    );
    initialize.mockImplementation(() => calls.push('initialize'));

    ConversationView.mounted.call({
      $store: { dispatch },
      initialize,
      $watch: watch,
      fetchConversationIfUnavailable,
    });

    expect(fetchConversationIfUnavailable).toHaveBeenCalledTimes(1);
    expect(initialize).toHaveBeenCalledTimes(1);
    expect(dispatch).toHaveBeenCalledWith('agents/get');
    expect(dispatch).toHaveBeenCalledWith('portals/index');
    expect(calls.indexOf('fetch-conversation')).toBeLessThan(
      calls.indexOf('initialize')
    );
  });

  it('fetches a missing deep-linked conversation through the store', () => {
    const dispatch = vi.fn();

    ConversationView.methods.fetchConversationIfUnavailable.call({
      conversationId: 1143,
      findConversation: () => null,
      $store: { dispatch },
    });

    expect(dispatch).toHaveBeenCalledWith('getConversation', 1143);
  });

  it('does not fetch when the deep-linked conversation is already available', () => {
    const dispatch = vi.fn();

    ConversationView.methods.fetchConversationIfUnavailable.call({
      conversationId: 1143,
      findConversation: () => ({ id: 1143 }),
      $store: { dispatch },
    });

    expect(dispatch).not.toHaveBeenCalledWith('getConversation', 1143);
  });
});
