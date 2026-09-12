/* global axios */
import ApiClient from '../ApiClient';

class AudioTranscriptionApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  create({ conversationId, file }) {
    const formData = new FormData();
    formData.append('audio', file, file.name);

    return axios.post(
      `${this.url}/${conversationId}/audio_transcription`,
      formData
    );
  }
}

export default new AudioTranscriptionApi();
