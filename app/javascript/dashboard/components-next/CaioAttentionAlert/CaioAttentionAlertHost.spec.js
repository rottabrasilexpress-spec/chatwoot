import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import CaioAttentionAlertHost from './CaioAttentionAlertHost.vue';

const alerts = ref([]);
const dispatch = vi.fn();
const push = vi.fn();

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => alerts,
  useStore: () => ({ dispatch }),
}));

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: ref(1) }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
}));

describe('CaioAttentionAlertHost', () => {
  beforeEach(() => {
    alerts.value = [
      {
        alert_id: 'alert-1',
        conversation_id: 42,
        inbox_id: 7,
        label: 'caio-atencao',
      },
    ];
    dispatch.mockClear();
    push.mockClear();
  });

  it('renders a global alert card and opens the conversation', async () => {
    const wrapper = mount(CaioAttentionAlertHost);

    expect(wrapper.get('[data-test-id="caio-attention-alert-host"]').classes()).toContain('fixed');
    expect(wrapper.text()).toContain('Nova conversa #42');

    await wrapper.get('button:last-child').trigger('click');

    expect(dispatch).toHaveBeenCalledWith(
      'caioAttentionAlerts/dismiss',
      'alert-1'
    );
    expect(push).toHaveBeenCalledWith({
      name: 'conversation_through_inbox',
      params: { accountId: 1, inbox_id: 7, conversation_id: 42 },
    });
  });

  it('dismisses the card without navigating', async () => {
    const wrapper = mount(CaioAttentionAlertHost);

    await wrapper.get('button[aria-label="Fechar alerta Caio Atenção"]').trigger('click');

    expect(dispatch).toHaveBeenCalledWith(
      'caioAttentionAlerts/dismiss',
      'alert-1'
    );
    expect(push).not.toHaveBeenCalled();
  });
});
