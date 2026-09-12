import {
  actions,
  getters,
  findSidebarLabel,
  isSidebarLabelTitle,
  SIDEBAR_LABEL_COUNTS_MUTATION,
  SIDEBAR_LABEL_DEFINITIONS,
} from '../../labels';

const buildState = records => ({
  records,
  sidebarLabelCounts: {},
});

describe('labels sidebar counts', () => {
  it('loads conversation counts for the Rotta sidebar labels', async () => {
    const records = [
      {
        id: 1,
        title: 'Kelvin',
        contacts_count: 99,
        conversations_count: 11,
        show_on_sidebar: false,
      },
      {
        id: 2,
        title: 'caio-atencao',
        contacts_count: 99,
        conversations_count: 7,
        show_on_sidebar: true,
      },
      {
        id: 3,
        title: 'Clientes Fechados',
        contacts_count: 99,
        conversations_count: 4,
        show_on_sidebar: false,
      },
      {
        id: 4,
        title: 'Emitir Contrato',
        contacts_count: 99,
        conversations_count: 2,
        show_on_sidebar: false,
      },
      {
        id: 5,
        title: 'FINALIZADOS',
        contacts_count: 99,
        conversations_count: 1,
        show_on_sidebar: false,
      },
    ];
    const moduleState = buildState(records);
    const commit = vi.fn();

    await actions.getSidebarCounts({ state: moduleState, commit });

    expect(commit).toHaveBeenCalledWith(SIDEBAR_LABEL_COUNTS_MUTATION, {
      budget: 11,
      caioAttention: 7,
      contractIssuance: 2,
      closedClients: 4,
      finalized: 1,
    });
  });

  it('ignores contact-only counts when a label has no active conversations', async () => {
    const moduleState = buildState([
      { id: 1, title: 'Kelvin', contacts_count: 3, conversations_count: 0 },
    ]);
    const commit = vi.fn();

    await actions.getSidebarCounts({ state: moduleState, commit });

    expect(commit).toHaveBeenCalledWith(SIDEBAR_LABEL_COUNTS_MUTATION, {
      budget: 0,
      caioAttention: 0,
      contractIssuance: 0,
      closedClients: 0,
      finalized: 0,
    });
    expect(getters.getSidebarLabelCount(moduleState)('budget')).toBe(0);
  });

  it('clears stale counts when a label disappears between refreshes', async () => {
    const moduleState = {
      records: [{ id: 1, title: 'Kelvin', conversations_count: 0 }],
      sidebarLabelCounts: {
        budget: 1,
        caioAttention: 1,
        contractIssuance: 1,
        closedClients: 1,
        finalized: 1,
      },
    };
    const commit = vi.fn();

    await actions.getSidebarCounts({ state: moduleState, commit });

    expect(commit).toHaveBeenCalledWith(SIDEBAR_LABEL_COUNTS_MUTATION, {
      budget: 0,
      caioAttention: 0,
      contractIssuance: 0,
      closedClients: 0,
      finalized: 0,
    });
  });

  it('clears every count when the label catalog is empty', async () => {
    const moduleState = {
      records: [],
      sidebarLabelCounts: {
        budget: 1,
        caioAttention: 1,
        contractIssuance: 1,
        closedClients: 1,
        finalized: 1,
      },
    };
    const commit = vi.fn();

    await actions.getSidebarCounts({ state: moduleState, commit });

    expect(commit).toHaveBeenCalledWith(SIDEBAR_LABEL_COUNTS_MUTATION, {
      budget: 0,
      caioAttention: 0,
      contractIssuance: 0,
      closedClients: 0,
      finalized: 0,
    });
  });

  it('resolves labels case-insensitively and ignores accents and separators', () => {
    const records = [
      { id: 1, title: 'Kélvin' },
      { id: 2, title: 'CAIO ATENÇÃO' },
      { id: 3, title: 'Emitir Contrato' },
      { id: 4, title: 'clientes_fechados' },
      { id: 5, title: 'FINALIZADOS' },
    ];

    expect(
      SIDEBAR_LABEL_DEFINITIONS.map(
        definition => findSidebarLabel(records, definition)?.title
      )
    ).toEqual([
      'Kélvin',
      'CAIO ATENÇÃO',
      'Emitir Contrato',
      'clientes_fechados',
      'FINALIZADOS',
    ]);
    expect(
      SIDEBAR_LABEL_DEFINITIONS.map(definition => definition.color)
    ).toEqual(['#f59e0b', '#1e3a8a', '#7c3aed', '#16a34a', '#dc2626']);
  });

  it('recognizes the finalized label in route and API title forms', () => {
    expect(isSidebarLabelTitle('finalizados', 'finalized')).toBe(true);
    expect(isSidebarLabelTitle('FINALIZADOS', 'finalized')).toBe(true);
    expect(isSidebarLabelTitle('Emitir Contrato', 'finalized')).toBe(false);
  });
});
