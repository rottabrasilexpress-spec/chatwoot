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

    // eslint-disable-next-line class-methods-use-this
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
  const originalMediaRecorder = window.MediaRecorder;
  const originalSpeechRecognition = window.SpeechRecognition;
  const originalWebkitSpeechRecognition = window.webkitSpeechRecognition;

  afterEach(() => {
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: originalMediaDevices,
    });
    window.MediaRecorder = originalMediaRecorder;
    window.SpeechRecognition = originalSpeechRecognition;
    window.webkitSpeechRecognition = originalWebkitSpeechRecognition;
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
    window.MediaRecorder = buildMediaRecorder();

    const wrapper = mount(DictationRecorder, {
      global: { mocks: { $t: value => value } },
    });
    await nextTick();
    wrapper.vm.stopRecording();

    await vi.waitFor(() =>
      expect(wrapper.emitted('finishRecord')).toBeTruthy()
    );

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
    window.MediaRecorder = buildMediaRecorder();

    const wrapper = mount(DictationRecorder, {
      global: { mocks: { $t: value => value } },
    });
    await vi.waitFor(() => expect(wrapper.emitted('recordError')).toBeTruthy());

    expect(wrapper.emitted('recordError')[0][0].error).toBe(error);
  });

  it('captures a pt-BR browser transcript alongside the recorded file', async () => {
    function FakeSpeechRecognition() {}
    function startSpeechRecognition() {}
    function stopSpeechRecognition() {
      this.onresult?.({
        resultIndex: 0,
        results: [
          {
            isFinal: true,
            0: { transcript: 'Olá, tudo bem?' },
          },
        ],
      });
      this.onend?.();
    }

    function abortSpeechRecognition() {
      this.onend?.();
    }

    FakeSpeechRecognition.prototype.start = startSpeechRecognition;
    FakeSpeechRecognition.prototype.stop = stopSpeechRecognition;
    FakeSpeechRecognition.prototype.abort = abortSpeechRecognition;

    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      value: {
        getUserMedia: vi.fn().mockResolvedValue({
          getTracks: () => [{ stop: vi.fn() }],
        }),
      },
    });
    window.MediaRecorder = buildMediaRecorder();
    window.SpeechRecognition = FakeSpeechRecognition;

    const wrapper = mount(DictationRecorder, {
      global: { mocks: { $t: value => value } },
    });
    await nextTick();
    wrapper.vm.stopRecording();

    await vi.waitFor(() =>
      expect(wrapper.emitted('finishRecord')).toBeTruthy()
    );
    const [file] = wrapper.emitted('finishRecord')[0];
    expect(file.nativeTranscript).toBe('Olá, tudo bem?');
  });
});
