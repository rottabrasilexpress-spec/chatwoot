import { useBulkActionsHotKeys } from '../useBulkActionsHotKeys';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

vi.mock('dashboard/composables/store');
vi.mock('vue-i18n');
vi.mock('shared/helpers/mitt');

describe('useBulkActionsHotKeys', () => {
  let store;

  beforeEach(() => {
    store = {
      getters: {
        'bulkActions/getSelectedConversationIds': [],
      },
    };

    useStore.mockReturnValue(store);
    useMapGetter.mockImplementation(key => ({
      value: store.getters[key],
    }));

    useI18n.mockReturnValue({ t: vi.fn(key => key) });
  });

  it('does not offer conversation status changes through bulk command actions', () => {
    store.getters['bulkActions/getSelectedConversationIds'] = [1, 2, 3];
    const { bulkActionsHotKeys } = useBulkActionsHotKeys();

    expect(bulkActionsHotKeys.value).toEqual([]);
  });

  it('returns an empty array when no conversations are selected', () => {
    store.getters['bulkActions/getSelectedConversationIds'] = [];
    const { bulkActionsHotKeys } = useBulkActionsHotKeys();

    expect(bulkActionsHotKeys.value).toEqual([]);
  });
});
