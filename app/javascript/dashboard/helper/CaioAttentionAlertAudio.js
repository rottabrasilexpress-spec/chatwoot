const CAIO_ATTENTION_AUDIO_URL = '/audio/dashboard/bell.mp3';

export const playCaioAttentionAlert = () => {
  const audio = new Audio(CAIO_ATTENTION_AUDIO_URL);
  audio.volume = 1;

  // This alert intentionally does not consult the normal dashboard audio
  // preferences. Browser autoplay policy may still reject playback; the card
  // remains visible in that case.
  const playback = audio.play();
  playback?.catch?.(() => {});
  return audio;
};

export default {
  play: playCaioAttentionAlert,
};
