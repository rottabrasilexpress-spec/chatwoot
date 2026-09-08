import messageAPI, { buildCreatePayload } from '../../inbox/message';
import ApiClient from '../../ApiClient';

describe('#ConversationAPI', () => {
  it('creates correct instance', () => {
    expect(messageAPI).toBeInstanceOf(ApiClient);
    expect(messageAPI).toHaveProperty('get');
    expect(messageAPI).toHaveProperty('show');
    expect(messageAPI).toHaveProperty('create');
    expect(messageAPI).toHaveProperty('update');
    expect(messageAPI).toHaveProperty('delete');
    expect(messageAPI).toHaveProperty('getPreviousMessages');
    expect(messageAPI).toHaveProperty('edit');
    expect(messageAPI).toHaveProperty('react');
    expect(messageAPI).toHaveProperty('pin');
    expect(messageAPI).toHaveProperty('forward');
    expect(messageAPI).toHaveProperty('star');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#getPreviousMessages', () => {
      messageAPI.getPreviousMessages({
        conversationId: 12,
        before: 4573,
      });
      expect(axiosMock.get).toHaveBeenCalledWith(
        `/api/v1/conversations/12/messages`,
        {
          params: {
            before: 4573,
          },
        }
      );
    });

    it('uses the message action endpoints', async () => {
      await messageAPI.edit(12, 34, 'edited');
      await messageAPI.react(12, 34, '👍');
      await messageAPI.pin(12, 34, true, 7);
      await messageAPI.forward(12, 34, 56);
      await messageAPI.star(12, 34, true);

      expect(axiosMock.post).toHaveBeenNthCalledWith(
        1,
        '/api/v1/conversations/12/messages/34/edit',
        { text: 'edited' }
      );
      expect(axiosMock.post).toHaveBeenNthCalledWith(
        2,
        '/api/v1/conversations/12/messages/34/react',
        { emoji: '👍' }
      );
      expect(axiosMock.post).toHaveBeenNthCalledWith(
        3,
        '/api/v1/conversations/12/messages/34/pin',
        { pin: true, duration: 7 }
      );
      expect(axiosMock.post).toHaveBeenNthCalledWith(
        4,
        '/api/v1/conversations/12/messages/34/forward',
        { target_conversation_id: 56 }
      );
      expect(axiosMock.post).toHaveBeenNthCalledWith(
        5,
        '/api/v1/conversations/12/messages/34/star',
        { starred: true }
      );
    });
  });
  describe('#buildCreatePayload', () => {
    it('builds form payload if file is available', () => {
      const formPayload = buildCreatePayload({
        message: 'test content',
        echoId: 12,
        isPrivate: true,
        contentAttributes: { in_reply_to: 12 },
        files: [new Blob(['test-content'], { type: 'application/pdf' })],
      });
      expect(formPayload).toBeInstanceOf(FormData);
      expect(formPayload.get('content')).toEqual('test content');
      expect(formPayload.get('echo_id')).toEqual('12');
      expect(formPayload.get('private')).toEqual('true');
      expect(formPayload.get('cc_emails')).toEqual('');
      expect(formPayload.get('bcc_emails')).toEqual('');
      expect(formPayload.get('content_attributes')).toEqual(
        '{"in_reply_to":12}'
      );
    });

    it('builds object payload if file is not available', () => {
      expect(
        buildCreatePayload({
          message: 'test content',
          isPrivate: false,
          echoId: 12,
          contentAttributes: { in_reply_to: 12 },
        })
      ).toEqual({
        content: 'test content',
        private: false,
        echo_id: 12,
        content_attributes: { in_reply_to: 12 },
        cc_emails: '',
        bcc_emails: '',
        to_emails: '',
        template_params: undefined,
      });
    });

    it('appends is_voice_message when isVoiceMessage is true', () => {
      const formPayload = buildCreatePayload({
        message: 'voice message',
        echoId: 42,
        isPrivate: false,
        files: [new Blob(['audio-data'], { type: 'audio/ogg' })],
        isVoiceMessage: true,
      });
      expect(formPayload).toBeInstanceOf(FormData);
      expect(formPayload.get('is_voice_message')).toEqual('true');
    });

    it('does not append is_voice_message when isVoiceMessage is false', () => {
      const formPayload = buildCreatePayload({
        message: 'regular audio',
        echoId: 43,
        isPrivate: false,
        files: [new Blob(['audio-data'], { type: 'audio/ogg' })],
        isVoiceMessage: false,
      });
      expect(formPayload).toBeInstanceOf(FormData);
      expect(formPayload.get('is_voice_message')).toBeNull();
    });
  });
});
