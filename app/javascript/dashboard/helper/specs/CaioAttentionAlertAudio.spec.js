import { beforeEach, describe, expect, it, vi } from 'vitest';
import { playCaioAttentionAlert } from '../CaioAttentionAlertAudio';

describe('CaioAttentionAlertAudio', () => {
  beforeEach(() => {
    global.Audio = vi.fn(() => ({
      volume: 0,
      play: vi.fn(() => Promise.resolve()),
    }));
  });

  it('plays the dedicated alert at full volume independently of normal settings', () => {
    const audio = playCaioAttentionAlert();

    expect(Audio).toHaveBeenCalledWith('/audio/dashboard/bell.mp3');
    expect(audio.volume).toBe(1);
    expect(audio.play).toHaveBeenCalledTimes(1);
  });

  it('keeps the visual alert path alive when autoplay is blocked', () => {
    global.Audio = vi.fn(() => ({
      volume: 0,
      play: vi.fn(() => Promise.reject(new Error('NotAllowedError'))),
    }));

    expect(() => playCaioAttentionAlert()).not.toThrow();
  });
});
