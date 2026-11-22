import { flushPromises, shallowMount } from '@vue/test-utils';
import CopilotInput from './CopilotInput.vue';
import AudioTranscriptionAPI from 'dashboard/api/inbox/audioTranscription';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/inbox/audioTranscription', () => ({
  default: { create: vi.fn() },
}));

describe('CopilotInput dictation', () => {
  it('appends a transcript to the private draft and waits for manual submission', async () => {
    AudioTranscriptionAPI.create.mockResolvedValue({
      data: { text: 'Há itens novos?' },
    });
    const wrapper = shallowMount(CopilotInput, {
      props: { dictationConversationId: 3861 },
      global: { mocks: { $t: key => key } },
    });
    await wrapper.get('textarea').setValue('Confira o inventário.');
    await wrapper
      .get('[aria-label="CONVERSATION.COPILOT.DICTATE"]')
      .trigger('click');
    const file = new File(['simulated'], 'dictation.webm', {
      type: 'audio/webm',
    });
    wrapper
      .getComponent({ name: 'DictationRecorder' })
      .vm.$emit('finishRecord', file);
    await flushPromises();

    expect(AudioTranscriptionAPI.create).toHaveBeenCalledWith({
      conversationId: 3861,
      file,
    });
    expect(wrapper.get('textarea').element.value).toBe(
      'Confira o inventário.\nHá itens novos?'
    );
    expect(wrapper.emitted('send')).toBeUndefined();
    await wrapper.get('form').trigger('submit');
    expect(wrapper.emitted('send')).toEqual([
      ['Confira o inventário.\nHá itens novos?'],
    ]);
    wrapper.unmount();
  });
});
