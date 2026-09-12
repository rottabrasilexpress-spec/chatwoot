import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import DictationRecorder from './DictationRecorder.vue';

const buildMediaRecorder = () => {
  class FakeMediaRecorder {
    static isTypeSupported = vi.fn(() => true);

    constructor(stream, options = {}) {
      this.stream = stream;
      this.mimeType = options.mimeType || 'audio/webm';
    }

    start() {}

    stop() {
      this.ondataavailable?.({
        data: new Blob(['recorded audio'], { type: this.mimeType }),
      });
      this.onstop?.();
    }
  }

  return FakeMediaRecorder;
};

describe('DictationRecorder', () => {
  const originalMediaDevices = navigator.mediaDevices;
  const originalMediaRecorder = globalThis.MediaRecorder;

  afterEach(() => {
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: originalMediaDevices,
    });
    globalThis.MediaRecorder = originalMediaRecorder;
  });

  it('emits a browser-supported file and releases the microphone tracks', async () => {
    const stopTrack = vi.fn();
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: {
        getUserMedia: vi.fn().mockResolvedValue({
          getTracks: () => [{ stop: stopTrack }],
        }),
      },
    });
    globalThis.MediaRecorder = buildMediaRecorder();

    const wrapper = mount(DictationRecorder, {
      global: { mocks: { $t: value => value } },
    });
    await nextTick();
    wrapper.vm.stopRecording();

    const [file] = wrapper.emitted('finishRecord')[0];
    expect(file.type).toBe('audio/webm;codecs=opus');
    expect(file.name).toMatch(/^dictation-\d+\.webm$/);
    expect(stopTrack).toHaveBeenCalled();
  });

  it('reports denied microphone permission without throwing', async () => {
    const error = new DOMException('Permission denied', 'NotAllowedError');
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: { getUserMedia: vi.fn().mockRejectedValue(error) },
    });
    globalThis.MediaRecorder = buildMediaRecorder();

    const wrapper = mount(DictationRecorder, {
      global: { mocks: { $t: value => value } },
    });
    await vi.waitFor(() => expect(wrapper.emitted('record-error')).toBeTruthy());

    expect(wrapper.emitted('record-error')[0][0].error).toBe(error);
  });
});
