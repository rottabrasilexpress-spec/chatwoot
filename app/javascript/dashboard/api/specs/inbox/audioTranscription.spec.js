import audioTranscriptionAPI from '../../inbox/audioTranscription';
import ApiClient from '../../ApiClient';

describe('#AudioTranscriptionAPI', () => {
  it('uses the authenticated conversation transcription endpoint', async () => {
    const originalAxios = window.axios;
    const axiosMock = { post: vi.fn(() => Promise.resolve()) };
    window.axios = axiosMock;
    const file = new File(['audio'], 'dictation.webm', { type: 'audio/webm' });

    try {
      expect(audioTranscriptionAPI).toBeInstanceOf(ApiClient);
      await audioTranscriptionAPI.create({ conversationId: 12, file });

      const [url, formData] = axiosMock.post.mock.calls[0];
      expect(url).toBe('/api/v1/conversations/12/audio_transcription');
      expect(formData).toBeInstanceOf(FormData);
      expect(formData.get('audio').name).toBe('dictation.webm');
      expect(formData.get('audio').type).toBe('audio/webm');
    } finally {
      window.axios = originalAxios;
    }
  });
});
