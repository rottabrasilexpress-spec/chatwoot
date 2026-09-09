import MessagesView from '../MessagesView.vue';

describe('MessagesView', () => {
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
