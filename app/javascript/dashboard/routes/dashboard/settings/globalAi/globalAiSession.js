export const parseStoredGlobalAiThreadId = rawState => {
  if (!rawState) return null;

  try {
    const parsed = JSON.parse(rawState);
    const threadId = Number(parsed?.threadId);
    return Number.isInteger(threadId) && threadId > 0 ? threadId : null;
  } catch {
    return null;
  }
};

export const buildGlobalAiViewState = thread => {
  const serverMessages = Array.isArray(thread?.messages) ? thread.messages : [];
  const messages = serverMessages.flatMap(item => {
    const role = item?.message_type;
    const payload = item?.message || {};
    const content = role === 'assistant' ? payload.answer : payload.content;
    return content ? [{ role, content }] : [];
  });
  const latestAssistant = [...serverMessages]
    .reverse()
    .find(item => item?.message_type === 'assistant');

  return {
    threadId: Number(thread?.id) || null,
    messages,
    resultCards: Array.isArray(latestAssistant?.message?.cards)
      ? latestAssistant.message.cards
      : [],
  };
};
