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
});
