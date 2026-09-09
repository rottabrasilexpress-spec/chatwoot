import ContactAPI from '../../../../api/contacts';
import {
  actions,
  getters,
  findSidebarLabel,
  SIDEBAR_LABEL_COUNTS_MUTATION,
  SIDEBAR_LABEL_DEFINITIONS,
} from '../../labels';

vi.mock('../../../../api/contacts', () => ({
  default: {
    get: vi.fn(),
  },
}));

const buildState = records => ({
  records,
  sidebarLabelCounts: {},
});

describe('labels sidebar counts', () => {
  beforeEach(() => {
    ContactAPI.get.mockReset();
  });

  it('loads total contact counts for the three Rotta sidebar labels', async () => {
    const records = [
      { id: 1, title: 'Kelvin', show_on_sidebar: false },
      { id: 2, title: 'caio-atencao', show_on_sidebar: true },
      { id: 3, title: 'Clientes Fechados', show_on_sidebar: false },
    ];
    const moduleState = buildState(records);
    const commit = vi.fn();

    ContactAPI.get.mockImplementation((_page, _sort, label) =>
      Promise.resolve({
        data: {
          meta: {
            count: { Kelvin: 11, 'caio-atencao': 7, 'Clientes Fechados': 4 }[
              label
            ],
          },
        },
      })
    );

    await actions.getSidebarCounts({ state: moduleState, commit });

    expect(ContactAPI.get).toHaveBeenCalledTimes(3);
    expect(ContactAPI.get).toHaveBeenCalledWith(1, 'name', 'Kelvin');
    expect(ContactAPI.get).toHaveBeenCalledWith(1, 'name', 'caio-atencao');
    expect(ContactAPI.get).toHaveBeenCalledWith(1, 'name', 'Clientes Fechados');
    expect(commit).toHaveBeenCalledWith(SIDEBAR_LABEL_COUNTS_MUTATION, {
      budget: 11,
      caioAttention: 7,
      closedClients: 4,
    });
  });

  it('does not request a missing special label and keeps count lookup reactive', async () => {
    const moduleState = buildState([{ id: 1, title: 'Kelvin' }]);
    const commit = vi.fn();
    ContactAPI.get.mockResolvedValue({ data: { meta: { count: 3 } } });

    await actions.getSidebarCounts({ state: moduleState, commit });

    expect(ContactAPI.get).toHaveBeenCalledTimes(1);
    expect(commit).toHaveBeenCalledWith(SIDEBAR_LABEL_COUNTS_MUTATION, {
      budget: 3,
    });
    expect(getters.getSidebarLabelCount(moduleState)('budget')).toBe(0);
  });

  it('resolves labels case-insensitively and ignores accents and separators', () => {
    const records = [
      { id: 1, title: 'Kélvin' },
      { id: 2, title: 'CAIO ATENÇÃO' },
      { id: 3, title: 'clientes_fechados' },
    ];

    expect(
      SIDEBAR_LABEL_DEFINITIONS.map(
        definition => findSidebarLabel(records, definition)?.title
      )
    ).toEqual(['Kélvin', 'CAIO ATENÇÃO', 'clientes_fechados']);
    expect(
      SIDEBAR_LABEL_DEFINITIONS.map(definition => definition.color)
    ).toEqual(['#f59e0b', '#1e3a8a', '#16a34a']);
  });
});
