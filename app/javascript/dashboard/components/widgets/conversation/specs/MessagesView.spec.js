import MessagesView from '../MessagesView.vue';

describe('MessagesView', () => {
  it('starts at the latest message when opening a conversation', () => {
    const panel = { addEventListener: vi.fn() };
    const context = {
      $el: { querySelector: vi.fn(() => panel) },
      $nextTick: callback => callback(),
      setScrollParams: vi.fn(),
      handleScroll: vi.fn(),
      scrollToLatestOnOpen: vi.fn(),
      scrollToBottom: vi.fn(),
    };

    MessagesView.methods.addScrollListener.call(context);

    expect(context.scrollToLatestOnOpen).toHaveBeenCalledOnce();
    expect(context.scrollToBottom).not.toHaveBeenCalled();
  });

  it('starts at the latest message after switching conversations', () => {
    const context = {
      currentChat: { id: 43 },
      $route: { query: {} },
      $nextTick: callback => callback(),
      fetchAllAttachmentsFromCurrentChat: vi.fn(),
      fetchSuggestions: vi.fn(),
      loadAllPreviousMessages: vi.fn(),
      resetReplyEditorHeight: vi.fn(),
      scrollToLatestOnOpen: vi.fn(),
    };

    MessagesView.watch.currentChat.call(context, { id: 43 }, { id: 42 });

    expect(context.scrollToLatestOnOpen).toHaveBeenCalledOnce();
    expect(context.loadAllPreviousMessages).toHaveBeenCalledOnce();
  });

  it('preserves an explicit message link instead of forcing the latest message', () => {
    const context = {
      $route: { query: { messageId: '123' } },
      scrollToLatest: vi.fn(),
    };

    MessagesView.methods.scrollToLatestOnOpen.call(context);

    expect(context.scrollToLatest).not.toHaveBeenCalled();
  });

  it('positions the message panel at its actual scroll end', () => {
    const panel = { scrollHeight: 2400, scrollTop: 300 };
    const context = {
      conversationPanel: panel,
      hasNewMessages: true,
      newMessagesCount: 4,
      hasUserScrolled: true,
      $nextTick: callback => callback(),
    };

    MessagesView.methods.scrollToLatest.call(context);

    expect(panel.scrollTop).toBe(panel.scrollHeight);
    expect(context.hasNewMessages).toBe(false);
    expect(context.newMessagesCount).toBe(0);
    expect(context.hasUserScrolled).toBe(false);
  });

  it('loads every previous message page after the conversation is ready', async () => {
    const currentChat = {
      id: 42,
      dataFetched: true,
      allMessagesLoaded: false,
      messages: [{ id: 300 }],
    };
    const dispatch = vi
      .fn()
      .mockImplementationOnce(async () => {
        currentChat.messages.unshift({ id: 200 });
        return true;
      })
      .mockImplementationOnce(async () => {
        currentChat.messages.unshift({ id: 100 });
        return true;
      })
      .mockImplementationOnce(async () => {
        currentChat.allMessagesLoaded = true;
        return false;
      });

    const context = {
      currentChat,
      conversationPanel: { scrollHeight: 1000, scrollTop: 800 },
      historyLoadPromise: null,
      isLoadingPrevious: false,
      $store: { dispatch },
      $nextTick: callback => {
        callback?.();
        return Promise.resolve();
      },
      setScrollParams() {},
      scrollToLatestOnOpen: vi.fn(),
    };

    await MessagesView.methods.loadAllPreviousMessages.call(context);

    expect(dispatch).toHaveBeenNthCalledWith(1, 'fetchPreviousMessages', {
      conversationId: 42,
      before: 300,
    });
    expect(dispatch).toHaveBeenNthCalledWith(2, 'fetchPreviousMessages', {
      conversationId: 42,
      before: 200,
    });
    expect(dispatch).toHaveBeenNthCalledWith(3, 'fetchPreviousMessages', {
      conversationId: 42,
      before: 100,
    });
    expect(dispatch).toHaveBeenCalledTimes(3);
    expect(context.isLoadingPrevious).toBe(false);
  });

  it('returns to the latest message after older pages finish loading on open', async () => {
    const currentChat = {
      id: 42,
      dataFetched: true,
      allMessagesLoaded: false,
      messages: [{ id: 300 }],
    };
    const context = {
      currentChat,
      conversationPanel: { scrollHeight: 1000, scrollTop: 800 },
      historyLoadPromise: null,
      isLoadingPrevious: false,
      hasUserScrolled: false,
      $route: { query: {} },
      $store: {
        dispatch: vi.fn(async () => {
          currentChat.allMessagesLoaded = true;
          return false;
        }),
      },
      $nextTick: callback => {
        callback?.();
        return Promise.resolve();
      },
      setScrollParams() {},
      scrollToLatestOnOpen: vi.fn(),
    };

    await MessagesView.methods.loadAllPreviousMessages.call(context);

    expect(context.scrollToLatestOnOpen).toHaveBeenCalledOnce();
  });

  it('does not crash while a ready conversation has no message array yet', async () => {
    const dispatch = vi.fn();
    const context = {
      currentChat: { id: 42, dataFetched: true, messages: undefined },
      conversationPanel: { scrollHeight: 1000, scrollTop: 800 },
      historyLoadPromise: null,
      isLoadingPrevious: false,
      $store: { dispatch },
    };

    await MessagesView.methods.loadAllPreviousMessages.call(context);

    expect(dispatch).not.toHaveBeenCalled();
    expect(context.isLoadingPrevious).toBe(false);
  });

  it('deduplicates renderable echoes for API inboxes used by UAZAPI', () => {
    const stub = { id: 20, source_id: 'uazapi-echo', content: '' };
    const renderableEcho = {
      id: 21,
      source_id: 'uazapi-echo',
      content: 'Resposta da IA',
    };

    const messages = MessagesView.computed.getMessages.call({
      currentChat: { messages: [stub, renderableEcho] },
      isAWhatsAppChannel: false,
      isAPIInbox: true,
    });

    expect(messages).toEqual([renderableEcho]);
  });
});
