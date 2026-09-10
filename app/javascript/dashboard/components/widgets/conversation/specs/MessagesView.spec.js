import MessagesView from '../MessagesView.vue';

describe('MessagesView', () => {
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
