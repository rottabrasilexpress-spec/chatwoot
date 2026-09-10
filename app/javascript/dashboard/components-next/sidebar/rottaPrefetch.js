export const buildConversationPrefetchViews = ({
  common,
  unreadConversationType,
  priorityConversationType,
  archivedConversationType,
  sidebarLabelTitles = [],
}) => {
  const cacheCompatibleCommon = { ...common, perPage: 50 };
  const views = [
    {
      ...cacheCompatibleCommon,
      conversationType: unreadConversationType,
    },
    {
      ...cacheCompatibleCommon,
      conversationType: priorityConversationType,
    },
    {
      ...cacheCompatibleCommon,
      conversationType: archivedConversationType,
      labels: ['arquivado'],
    },
    ...sidebarLabelTitles.map(title => ({
      ...cacheCompatibleCommon,
      labels: [title],
    })),
  ];

  return views.filter(
    (view, index, collection) =>
      collection.findIndex(
        candidate => JSON.stringify(candidate) === JSON.stringify(view)
      ) === index
  );
};
