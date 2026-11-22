import { mount } from '@vue/test-utils';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import ConversationAiBrief from './ConversationAiBrief.vue';

describe('ConversationAiBrief', () => {
  it('lists each request, requires incomplete facts, then inserts a draft only', async () => {
    const listener = vi.fn(({ onInserted }) => onInserted());
    emitter.on(BUS_EVENTS.INSERT_CONVERSATION_AI_BRIEF_DRAFT, listener);
    const wrapper = mount(ConversationAiBrief, {
      props: {
        conversationId: 54,
        brief: {
          state: 'ready',
          version: '1',
          result: {
            topics: [
              { request: 'Incluir sofá', answer: 'Recalcular' },
              { request: 'Prazo de entrega', answer: 'Consultar a operação' },
            ],
            draft: 'O total fica em [NOVO VALOR].',
          },
        },
      },
      global: { mocks: { $t: key => key } },
    });

    expect(wrapper.text()).toContain('Incluir sofá');
    expect(wrapper.text()).toContain('Prazo de entrega');
    expect(wrapper.get('button').element.disabled).toBe(true);
    await wrapper.get('textarea').setValue('Confirmo o orçamento atualizado.');
    await wrapper.get('button').trigger('click');
    expect(listener).toHaveBeenCalledOnce();
    expect(listener).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: 54,
        text: 'Confirmo o orçamento atualizado.',
      })
    );
    expect(wrapper.get('button').element.disabled).toBe(true);
    wrapper.unmount();
    emitter.off(BUS_EVENTS.INSERT_CONVERSATION_AI_BRIEF_DRAFT, listener);
  });
});
