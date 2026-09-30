const normalizeText = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLocaleLowerCase('pt-BR');

const digitsOnly = value => String(value || '').replace(/\D/g, '');

export const conversationMatchesSearch = (conversation, query) => {
  const normalizedQuery = normalizeText(query.trim());
  if (!normalizedQuery) return true;

  const contact = conversation.contact || {};
  const sender = conversation.meta?.sender || {};
  const searchableFields = [
    conversation.id,
    conversation.display_id,
    sender.name,
    sender.phone_number,
    sender.email,
    contact.name,
    contact.phone_number,
    contact.email,
    conversation.contact_inbox?.source_id,
  ].filter(Boolean);

  if (normalizeText(searchableFields.join(' ')).includes(normalizedQuery)) {
    return true;
  }

  const phoneQuery = digitsOnly(query);
  if (!phoneQuery || !/^[+\d\s().-]+$/.test(query)) return false;

  const searchablePhoneNumbers = [
    sender.phone_number,
    contact.phone_number,
    conversation.contact_inbox?.source_id,
  ];

  return searchablePhoneNumbers.some(phone =>
    digitsOnly(phone).includes(phoneQuery)
  );
};

export const getConversationSearchResults = ({
  remoteResults = [],
  localResults = [],
  query,
}) => {
  const conversationsById = new Map();

  // The server is authoritative for fuzzy suggestions; an exact-only local
  // filter must not throw away the suggestions returned by PostgreSQL.
  [
    ...remoteResults,
    ...localResults.filter(conversation =>
      conversationMatchesSearch(conversation, query)
    ),
  ].forEach(conversation => {
    const key = conversation.id ?? conversation;
    if (!conversationsById.has(key)) {
      conversationsById.set(key, conversation);
    }
  });

  return [...conversationsById.values()];
};

export const getSearchConversationDestination = conversation => {
  const labels = (conversation.labels || []).map(label =>
    typeof label === 'string' ? label : label?.title
  );
  const normalizeLabel = label =>
    normalizeText(label).replace(/[^a-z0-9]/g, '');
  if (
    conversation.rotta_archived ||
    conversation.status === 'resolved' ||
    labels.some(label =>
      ['arquivado', 'arquivados'].includes(normalizeLabel(label))
    )
  ) {
    return { conversationType: 'archived' };
  }
  const groups = [
    ['finalizados'],
    ['clientesfechados'],
    ['emitircontrato'],
    ['caioatencao'],
    ['kelvin', 'kelvincaio'],
  ];
  const label = groups
    .map(group => labels.find(value => group.includes(normalizeLabel(value))))
    .find(Boolean);
  return label ? { label } : {};
};
