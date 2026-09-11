import { nextTick, ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import CopilotContainer from './CopilotContainer.vue';

const testState = vi.hoisted(() => ({
  dispatch: vi.fn(),
  refs: {},
  uiSettings: null,
  messageCounts: {},
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useConfig', () => ({
  useConfig: () => ({ isEnterprise: true }),
}));
vi.mock('dashboard/composables/useUISettings', async () => {
  const { ref: createRef } = await import('vue');
  const uiSettings = createRef({ is_copilot_panel_open: true });
  testState.uiSettings = uiSettings;
  return {
    useUISettings: () => ({
      uiSettings,
      updateUISettings: vi.fn(),
    }),
  };
});
vi.mock('@vueuse/core', () => ({
  useWindowSize: () => ({ width: ref(1024) }),
}));
vi.mock('dashboard/composables/store', async () => {
  const { ref: createRef } = await import('vue');
  const refs = {
    getCurrentUser: createRef({ id: 1 }),
    'captainAssistants/getRecords': createRef([{ id: 7 }]),
    'captainAssistants/getUIFlags': createRef({ fetchingList: false }),
    getCopilotAssistant: createRef(null),
    getSelectedChat: createRef({ id: 1 }),
    getLastEmailInSelectedChat: createRef({ message_type: 0 }),
    getCurrentAccountId: createRef(1),
    'accounts/isFeatureEnabledonAccount': createRef(() => true),
  };
  testState.refs = refs;

  const getMessagesForThreadId = threadId => {
    if (!threadId) return [];
    if (
      !Object.prototype.hasOwnProperty.call(testState.messageCounts, threadId)
    ) {
      return [{ id: threadId }];
    }
    return Array.from(
      { length: testState.messageCounts[threadId] || 0 },
      (_, index) => ({
        id: index + 1,
        message_type: 'assistant',
      })
    );
  };

  return {
    useMapGetter: key => refs[key],
    useStore: () => ({
      dispatch: testState.dispatch,
      getters: {
        'copilotMessages/getMessagesByThreadId': getMessagesForThreadId,
      },
    }),
  };
});

const mountComponent = () =>
  shallowMount(CopilotContainer, {
    global: {
      directives: { onClickOutside: {} },
      stubs: {
        Copilot: {
          name: 'Copilot',
          props: ['messages'],
          template: '<div />',
        },
      },
    },
  });

describe('CopilotContainer', () => {
  beforeEach(() => {
    testState.dispatch.mockReset();
    testState.dispatch.mockResolvedValue(undefined);
    testState.messageCounts = {};
    testState.uiSettings.value = { is_copilot_panel_open: true };
    testState.refs.getSelectedChat.value = { id: 1 };
  });

  it('clears the selected thread when the conversation changes', async () => {
    testState.dispatch.mockImplementation(action =>
      action === 'copilotThreads/create'
        ? Promise.resolve({ id: 99 })
        : Promise.resolve()
    );
    const wrapper = mountComponent();
    const copilot = wrapper.findComponent({ name: 'Copilot' });

    copilot.vm.$emit('sendMessage', 'Draft a reply');
    await flushPromises();
    expect(copilot.props('messages')).toEqual([{ id: 99 }]);

    testState.refs.getSelectedChat.value = { id: 2 };
    await nextTick();

    expect(copilot.props('messages')).toEqual([]);
  });

  it('loads the current conversation thread on initial mount', async () => {
    testState.uiSettings.value = {
      is_copilot_panel_open: true,
      is_conversation_ai_open: true,
    };
    testState.refs.getSelectedChat.value = { display_id: 2294 };
    testState.dispatch.mockImplementation((action, payload) => {
      if (action === 'copilotThreads/get') {
        return Promise.resolve([{ id: 55 }]);
      }
      if (action === 'copilotMessages/get') {
        testState.messageCounts[Number(payload)] = 1;
      }
      return Promise.resolve();
    });

    const wrapper = mountComponent();
    await flushPromises();

    expect(testState.dispatch).toHaveBeenCalledWith('copilotThreads/get', {
      conversation_id: 2294,
      request_type: 'conversation_ai',
    });
    expect(testState.dispatch).toHaveBeenCalledWith('copilotMessages/get', 55);
    expect(
      wrapper.findComponent({ name: 'Copilot' }).props('messages')
    ).toEqual([{ id: 1, message_type: 'assistant' }]);

    wrapper.unmount();
  });

  it('ignores a thread created for a conversation that is no longer selected', async () => {
    let resolveRequest;
    testState.dispatch.mockImplementation(action => {
      if (action !== 'copilotThreads/create') return Promise.resolve();
      return new Promise(resolve => {
        resolveRequest = resolve;
      });
    });
    const wrapper = mountComponent();
    const copilot = wrapper.findComponent({ name: 'Copilot' });

    copilot.vm.$emit('sendMessage', 'Draft a reply');
    await nextTick();
    testState.refs.getSelectedChat.value = { id: 2 };
    await nextTick();
    resolveRequest({ id: 99 });
    await flushPromises();

    expect(copilot.props('messages')).toEqual([]);
  });

  it('polls responses independently when two conversations are active', async () => {
    vi.useFakeTimers();
    testState.uiSettings.value = {
      is_copilot_panel_open: true,
      is_conversation_ai_open: true,
    };

    const messageGetCalls = new Map();
    let nextThreadId = 99;
    testState.dispatch.mockImplementation((action, payload) => {
      if (action === 'copilotThreads/get') return Promise.resolve([]);
      if (action === 'copilotThreads/create') {
        nextThreadId += 1;
        return Promise.resolve({ id: nextThreadId });
      }
      if (action === 'copilotMessages/get') {
        const threadId = Number(payload);
        const calls = (messageGetCalls.get(threadId) || 0) + 1;
        messageGetCalls.set(threadId, calls);
        // The second conversation already has an answer when the first poll
        // continues. The first thread must still be polled independently.
        if (threadId === 101 && calls === 1) {
          testState.messageCounts[threadId] = 1;
        }
        // The first conversation receives its answer on its second fetch.
        if (threadId === 100 && calls >= 2) {
          testState.messageCounts[threadId] = 1;
        }
      }
      return Promise.resolve();
    });

    const wrapper = mountComponent();
    const copilot = wrapper.findComponent({ name: 'Copilot' });

    copilot.vm.$emit('sendMessage', 'Pergunta do chat 1');
    await flushPromises();

    testState.refs.getSelectedChat.value = { id: 2 };
    await nextTick();
    await flushPromises();

    copilot.vm.$emit('sendMessage', 'Pergunta do chat 2');
    await flushPromises();
    await vi.advanceTimersByTimeAsync(2200);
    await flushPromises();

    expect(messageGetCalls.get(100)).toBeGreaterThanOrEqual(2);
    expect(messageGetCalls.get(101)).toBeGreaterThanOrEqual(1);

    wrapper.unmount();
    vi.useRealTimers();
  });
});
