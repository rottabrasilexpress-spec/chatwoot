import { defineComponent, ref } from 'vue';
import { mount } from '@vue/test-utils';
import AudioChip from './Audio.vue';
import { provideMessageContext } from '../provider.js';
import { MESSAGE_TYPES } from '../constants.js';

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref([]),
}));

const mountAudio = () => {
  const Host = defineComponent({
    components: { AudioChip },
    setup() {
      provideMessageContext({ messageType: ref(MESSAGE_TYPES.INCOMING) });
    },
    data: () => ({
      attachment: {
        dataUrl: 'https://example.com/audio.ogg',
        fileType: 'audio',
      },
    }),
    template: '<AudioChip :attachment="attachment" />',
  });

  return mount(Host, {
    global: { stubs: { Icon: true } },
  });
};

describe('message audio chip', () => {
  it('exposes playback speed controls and the current/total time', async () => {
    const wrapper = mountAudio();
    const speedButton = wrapper.get('[data-test="audio-speed"]');

    expect(speedButton.text()).toBe('1x');
    expect(wrapper.find('.rotta-audio__duration').text()).toContain('00:00');
    expect(wrapper.find('.rotta-audio__time-separator').exists()).toBe(true);

    await speedButton.trigger('click');

    expect(speedButton.text()).toBe('1.5x');
  });

  it('keeps the player stopped when browser playback is rejected', async () => {
    const wrapper = mountAudio();
    const audio = wrapper.get('audio').element;
    audio.play = vi.fn().mockRejectedValue(new Error('media unavailable'));

    await wrapper.get('.rotta-audio__play').trigger('click');
    await Promise.resolve();

    expect(audio.play).toHaveBeenCalledOnce();
    expect(wrapper.get('.rotta-audio__play').attributes('aria-label')).toBe(
      'Reproduzir áudio'
    );
  });

  it('shows the pause state only after browser playback starts', async () => {
    const wrapper = mountAudio();
    const audio = wrapper.get('audio').element;
    audio.play = vi.fn().mockResolvedValue(undefined);

    await wrapper.get('.rotta-audio__play').trigger('click');

    expect(wrapper.get('.rotta-audio__play').attributes('aria-label')).toBe(
      'Pausar áudio'
    );
  });
});
