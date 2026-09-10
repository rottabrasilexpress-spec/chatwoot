import ConversationView from '../ConversationView.vue';

describe('ConversationView deep-linked conversation loading', () => {
  it('requests a deep-linked conversation on mount before the list finishes', () => {
    const fetchConversationIfUnavailable = vi.fn();
    const initialize = vi.fn();
    const watch = vi.fn();
    const dispatch = vi.fn();

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
  });
});
