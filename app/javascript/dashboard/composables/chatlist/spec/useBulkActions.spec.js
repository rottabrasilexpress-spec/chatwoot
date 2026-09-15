import { mergeConversationLabels } from '../useBulkActions';
import { defineComponent } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { useBulkActions } from '../useBulkActions';
import { beginConversationLabelMutation } from 'dashboard/helper/conversationLabelMutationQueue';
import { emitter } from 'shared/helpers/mitt';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/useConversationRequiredAttributes', () => ({
  useConversationRequiredAttributes: () => ({
    checkMissingAttributes: () => ({ hasMissing: false, missing: [] }),
  }),
}));

describe('mergeConversationLabels', () => {
  it('changes labels without changing any activity metadata', () => {
    const conversation = {
      id: 42,
      labels: ['primeiro-contato'],
      timestamp: 1700000000,
      last_activity_at: 1700000000,
    };

    expect(
      mergeConversationLabels(conversation, {
        add: ['segundo-contato'],
        remove: ['primeiro-contato'],
      })
    ).toEqual(['segundo-contato']);
    expect(conversation.timestamp).toBe(1700000000);
    expect(conversation.last_activity_at).toBe(1700000000);
  });

  it('deduplicates labels and accepts label objects from API payloads', () => {
    expect(
      mergeConversationLabels(
        { labels: [{ title: 'primeiro-contato' }, 'segundo-contato'] },
        { add: ['segundo-contato', 'terceiro-contato'] }
      )
    ).toEqual(['primeiro-contato', 'segundo-contato', 'terceiro-contato']);
  });

  it('makes archived the only label when it is added', () => {
    expect(
      mergeConversationLabels(
        { labels: ['primeiro-contato', 'orcamento-feito'] },
        { add: ['[1] arquivado'] }
      )
    ).toEqual(['[1] arquivado']);
  });
});

describe('single-conversation label updates', () => {
  it('uses the synchronous label mutation path instead of the async bulk job', async () => {
    const bulkProcess = vi.fn();
    const store = createStore({
      state: {
        conversations: [{ id: 2441, labels: ['primeiro-contato'] }],
      },
      getters: {
        getConversationById: state => id =>
          state.conversations.find(conversation => conversation.id === id),
      },
      mutations: {
        updateConversation(state, conversation) {
          state.conversations = state.conversations.map(item =>
            item.id === conversation.id ? conversation : item
          );
        },
      },
      actions: {
        updateConversation({ commit }, conversation) {
          commit('updateConversation', conversation);
        },
      },
      modules: {
        bulkActions: {
          namespaced: true,
          getters: { getSelectedConversationIds: () => [] },
          actions: {
            process: bulkProcess,
            clearSelectedConversationIds: vi.fn(),
          },
        },
        conversationLabels: {
          namespaced: true,
          actions: { mutate: vi.fn().mockResolvedValue(true) },
        },
        labels: {
          namespaced: true,
          actions: { get: vi.fn() },
        },
      },
    });
    const dispatchSpy = vi.spyOn(store, 'dispatch');
    const Harness = defineComponent({
      setup() {
        return useBulkActions();
      },
      template: '<div />',
    });
    const wrapper = mount(Harness, { global: { plugins: [store] } });

    await wrapper.vm.onAssignLabels(['emitir-contrato'], 2441);
    await flushPromises();

    expect(dispatchSpy).toHaveBeenCalledWith('conversationLabels/mutate', {
      conversationId: 2441,
      add: ['emitir-contrato'],
    });
    expect(bulkProcess).not.toHaveBeenCalled();
    wrapper.unmount();
  });

  it('suppresses a context-menu success toast when a newer mutation starts during refresh', async () => {
    let finishLabelRefresh;
    const version = beginConversationLabelMutation([2442]).get('2442');
    const labelMutation = vi
      .fn()
      .mockResolvedValue({ status: 'success', version });
    const store = createStore({
      modules: {
        bulkActions: {
          namespaced: true,
          getters: { getSelectedConversationIds: () => [] },
          actions: {
            process: vi.fn(),
            clearSelectedConversationIds: vi.fn(),
          },
        },
        conversationLabels: {
          namespaced: true,
          actions: { mutate: labelMutation },
        },
        labels: {
          namespaced: true,
          actions: {
            get: vi.fn(
              () =>
                new Promise(resolve => {
                  finishLabelRefresh = resolve;
                })
            ),
          },
        },
      },
    });
    const Harness = defineComponent({
      setup() {
        return useBulkActions();
      },
      template: '<div />',
    });
    const wrapper = mount(Harness, { global: { plugins: [store] } });
    const alerts = [];
    const collectAlert = payload => alerts.push(payload);
    emitter.on('newToastMessage', collectAlert);

    const update = wrapper.vm.onAssignLabels(['emitir-contrato'], 2442);
    await vi.waitFor(() => expect(finishLabelRefresh).toBeTypeOf('function'));
    beginConversationLabelMutation([2442]);
    finishLabelRefresh();
    await update;
    await flushPromises();

    emitter.off('newToastMessage', collectAlert);
    expect(alerts).toEqual([]);
    wrapper.unmount();
  });
});
