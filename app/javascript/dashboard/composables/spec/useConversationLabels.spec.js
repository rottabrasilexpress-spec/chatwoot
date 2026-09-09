import { useConversationLabels } from '../useConversationLabels';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { emitter } from 'shared/helpers/mitt';

vi.mock('dashboard/composables/store');

describe('useConversationLabels', () => {
  let store;
  let getters;

  beforeEach(() => {
    store = {
      getters: {
        'conversationLabels/getConversationLabels': vi.fn(),
        'conversationLabels/hasConversationLabels': vi.fn(() => true),
      },
      dispatch: vi.fn(),
    };
    getters = {
      getSelectedChat: { value: { id: 1 } },
      'labels/getLabels': {
        value: [
          { id: 1, title: 'Label 1' },
          { id: 2, title: 'Label 2' },
          { id: 3, title: 'Label 3' },
        ],
      },
    };

    useStore.mockReturnValue(store);
    useStoreGetters.mockReturnValue(getters);
  });

  it('should return the correct computed properties', () => {
    store.getters['conversationLabels/getConversationLabels'].mockReturnValue([
      'Label 1',
      'Label 2',
    ]);
    const { accountLabels, savedLabels, activeLabels, inactiveLabels } =
      useConversationLabels();

    expect(accountLabels.value).toEqual(getters['labels/getLabels'].value);
    expect(savedLabels.value).toEqual(['Label 1', 'Label 2']);
    expect(activeLabels.value).toEqual([
      { id: 1, title: 'Label 1' },
      { id: 2, title: 'Label 2' },
    ]);
    expect(inactiveLabels.value).toEqual([{ id: 3, title: 'Label 3' }]);
  });

  it('should update labels correctly', async () => {
    store.dispatch.mockResolvedValue(true);
    const { onUpdateLabels } = useConversationLabels();
    await onUpdateLabels(['Label 1', 'Label 3']);

    expect(store.dispatch).toHaveBeenCalledWith('conversationLabels/update', {
      conversationId: 1,
      labels: ['Label 1', 'Label 3'],
    });
  });

  it('announces label additions and removals after a successful update', async () => {
    store.dispatch.mockResolvedValue(true);
    store.getters['conversationLabels/getConversationLabels'].mockReturnValue([
      'Label 1',
      'Label 2',
    ]);
    const alerts = [];
    const collectAlert = ({ message }) => alerts.push(message);
    emitter.on('newToastMessage', collectAlert);

    const { onUpdateLabels } = useConversationLabels();
    await onUpdateLabels(['Label 1', 'Label 3']);

    emitter.off('newToastMessage', collectAlert);
    expect(alerts).toEqual([
      'Etiqueta "Label 3" adicionada à conversa.',
      'Etiqueta "Label 2" removida da conversa.',
    ]);
  });

  it('uses labels from the selected conversation until the cache is hydrated', () => {
    store.getters['conversationLabels/hasConversationLabels'].mockReturnValue(
      false
    );
    getters.getSelectedChat.value = {
      id: 42,
      labels: ['kelvin-caio'],
    };

    const { savedLabels } = useConversationLabels();

    expect(savedLabels.value).toEqual(['kelvin-caio']);
  });

  it('should add a label to the conversation', () => {
    store.getters['conversationLabels/getConversationLabels'].mockReturnValue([
      'Label 1',
    ]);
    const { addLabelToConversation } = useConversationLabels();

    addLabelToConversation({ title: 'Label 2' });

    expect(store.dispatch).toHaveBeenCalledWith('conversationLabels/update', {
      conversationId: 1,
      labels: ['Label 1', 'Label 2'],
    });
  });

  it('should remove a label from the conversation', () => {
    store.getters['conversationLabels/getConversationLabels'].mockReturnValue([
      'Label 1',
      'Label 2',
    ]);
    const { removeLabelFromConversation } = useConversationLabels();

    removeLabelFromConversation('Label 2');

    expect(store.dispatch).toHaveBeenCalledWith('conversationLabels/update', {
      conversationId: 1,
      labels: ['Label 1'],
    });
  });
});
