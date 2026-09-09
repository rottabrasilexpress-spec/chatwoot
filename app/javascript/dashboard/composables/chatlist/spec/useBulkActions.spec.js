import { mergeConversationLabels } from '../useBulkActions';

describe('mergeConversationLabels', () => {
  it('changes labels without changing any activity metadata', () => {
    const conversation = {
      id: 42,
      labels: ['primeiro-contato'],
      timestamp: 1700000000,
      last_activity_at: 1700000000,
    };

    expect(
      mergeConversationLabels(conversation, {
        add: ['segundo-contato'],
        remove: ['primeiro-contato'],
      })
    ).toEqual(['segundo-contato']);
    expect(conversation.timestamp).toBe(1700000000);
    expect(conversation.last_activity_at).toBe(1700000000);
  });

  it('deduplicates labels and accepts label objects from API payloads', () => {
    expect(
      mergeConversationLabels(
        { labels: [{ title: 'primeiro-contato' }, 'segundo-contato'] },
        { add: ['segundo-contato', 'terceiro-contato'] }
      )
    ).toEqual(['primeiro-contato', 'segundo-contato', 'terceiro-contato']);
  });
});
