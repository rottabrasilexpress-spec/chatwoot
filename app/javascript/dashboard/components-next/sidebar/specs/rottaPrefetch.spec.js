import { buildConversationPrefetchViews } from '../rottaPrefetch';

describe('buildConversationPrefetchViews', () => {
  it('builds only cache-compatible auxiliary views', () => {
    const views = buildConversationPrefetchViews({
      common: {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
      },
      unreadConversationType: 'unread',
      priorityConversationType: 'priority',
      archivedConversationType: 'archived',
      sidebarLabelTitles: [
        'Kelvin',
        'Caio Atenção',
        'Emitir Contrato',
        'Clientes fechados 🤝',
        'FINALIZADOS',
      ],
    });

    expect(views).toEqual([
      {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
        perPage: 50,
        conversationType: 'unread',
      },
      {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
        perPage: 50,
        conversationType: 'priority',
      },
      {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
        perPage: 50,
        conversationType: 'archived',
        labels: ['arquivado'],
      },
      {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
        perPage: 50,
        labels: ['Kelvin'],
      },
      {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
        perPage: 50,
        labels: ['Caio Atenção'],
      },
      {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
        perPage: 50,
        labels: ['Emitir Contrato'],
      },
      {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
        perPage: 50,
        labels: ['Clientes fechados 🤝'],
      },
      {
        assigneeType: 'all',
        status: 'all',
        sortBy: 'last_activity_at_desc',
        page: 1,
        perPage: 50,
        labels: ['FINALIZADOS'],
      },
    ]);
  });
});
