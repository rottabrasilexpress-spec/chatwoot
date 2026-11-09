import types from 'dashboard/store/mutation-types';

// Reuse confirmed read/message events; do not poll or copy unrelated fields.
export const subscribeToConversationReadState = (store, onReadState) =>
  store.subscribe(({ type, payload }) => {
    let readState;
    if (type === types.UPDATE_MESSAGE_UNREAD_COUNT) {
      readState = {
        id: payload.id,
        unread_count: payload.unreadCount ?? 0,
        agent_last_seen_at: payload.lastSeen,
      };
    } else if (type === types.UPDATE_CONVERSATION) {
      readState = payload;
    } else if (type === types.ADD_MESSAGE) {
      readState = { ...payload.conversation, id: payload.conversation_id };
    }
    if (readState?.id && readState.unread_count !== undefined) {
      onReadState(readState);
    }
  });

export const applyConversationReadState = (records, readState) => {
  if (!Array.isArray(records)) return records;
  const index = records.findIndex(record => record.id === readState.id);
  if (index === -1) return records;
  if (
    records[index].unread_count === readState.unread_count &&
    (readState.agent_last_seen_at === undefined ||
      records[index].agent_last_seen_at === readState.agent_last_seen_at)
  ) {
    return records;
  }

  const updated = { ...records[index], unread_count: readState.unread_count };
  if (readState.agent_last_seen_at !== undefined) {
    updated.agent_last_seen_at = readState.agent_last_seen_at;
  }
  const result = [...records];
  result[index] = updated;
  return result;
};
