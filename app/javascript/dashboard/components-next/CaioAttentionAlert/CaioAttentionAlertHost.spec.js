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
  const mountAlert = () =>
    mount(CaioAttentionAlertHost, {
      global: {
        mocks: {
          $t: (key, params = {}) => {
            if (key.endsWith('NEW_CONVERSATION')) {
              return `Nova conversa #${params.id}`;
            }
            if (key.endsWith('DISMISS')) return 'Fechar alerta Caio Atenção';
            if (key.endsWith('OPEN')) return 'Abrir conversa';
            return key;
          },
        },
      },
    });

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
    const wrapper = mountAlert();

    expect(
      wrapper.get('[data-test-id="caio-attention-alert-host"]').classes()
    ).toContain('fixed');
    expect(wrapper.text()).toContain('Nova conversa #42');

    await wrapper
      .get('[data-test-id="caio-attention-alert"] > button')
      .trigger('click');

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
    const wrapper = mountAlert();

    await wrapper
      .get('[data-test-id="caio-attention-alert"] > div button')
      .trigger('click');

    expect(dispatch).toHaveBeenCalledWith(
      'caioAttentionAlerts/dismiss',
      'alert-1'
    );
    expect(push).not.toHaveBeenCalled();
  });
});
