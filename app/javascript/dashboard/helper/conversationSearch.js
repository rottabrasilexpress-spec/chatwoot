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
  const labels = (conversation.labels || []).map(label =>
    typeof label === 'string' ? label : label?.title
  );
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
    conversation.last_non_activity_message?.content,
    ...labels,
  ].filter(Boolean);

  if (normalizeText(searchableFields.join(' ')).includes(normalizedQuery)) {
    return true;
  }

  const phoneQuery = digitsOnly(query);
  if (phoneQuery.length < 4) return false;

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

  [...remoteResults, ...localResults].forEach(conversation => {
    const key = conversation.id ?? conversation;
    if (!conversationsById.has(key)) {
      conversationsById.set(key, conversation);
    }
  });

  return [...conversationsById.values()].filter(conversation =>
    conversationMatchesSearch(conversation, query)
  );
};
