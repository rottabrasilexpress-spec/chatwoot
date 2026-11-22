import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import useConversationAiBrief from './useConversationAiBrief';

describe('useConversationAiBrief', () => {
  it('opens once for the active conversation and makes no request for Caio', async () => {
    const accountId = ref(1);
    const conversationId = ref(44);
    const chat = ref({ id: 44, labels: ['Caio Atenção'] });
    const user = ref({ id: 2 });
    const lastPublicMessage = ref(null);
    const openPanel = vi.fn();
    const get = vi.fn().mockResolvedValue({
      status: 200,
      data: { state: 'ready', version: 'ticket-1' },
    });
    vi.stubGlobal('axios', { get });
    vi.stubGlobal('chatwootConfig', {
      rottaAttentionRequesterUserId: '1',
      rottaConversationAiBriefAccountId: 1,
    });
    const wrapper = mount({
      setup() {
        return useConversationAiBrief({
          accountId,
          conversationId,
          chat,
          user,
          lastPublicMessage,
          openPanel,
        });
      },
      template: '<div>{{ brief?.state }}</div>',
    });

    await flushPromises();
    expect(get).not.toHaveBeenCalled();
    user.value = { id: 1 };
    await flushPromises();
    expect(wrapper.text()).toBe('ready');
    expect(openPanel).toHaveBeenCalledOnce();

    emitter.emit(BUS_EVENTS.CONVERSATION_AI_BRIEF_UPDATED, {
      account_id: 1,
      conversation_id: 43,
    });
    expect(get).toHaveBeenCalledOnce();
    emitter.emit(BUS_EVENTS.CONVERSATION_AI_BRIEF_UPDATED, {
      account_id: 1,
      conversation_id: 44,
    });
    await flushPromises();
    expect(get).toHaveBeenCalledTimes(2);
    expect(openPanel).toHaveBeenCalledOnce();

    chat.value = { id: 44, labels: [] };
    await flushPromises();
    expect(wrapper.text()).toBe('');
    wrapper.unmount();
    vi.unstubAllGlobals();
  });
});
