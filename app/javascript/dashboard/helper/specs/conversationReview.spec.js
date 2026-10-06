import {
  createReviewPoint,
  reviewConversationEligible,
  reviewViewKey,
  reviewConversationPath,
  normalizeReviewFilters,
} from '../conversationReview';
const context = {
  label: '',
  conversationType: '',
  status: 'all',
  assigneeType: 'all',
  filters: [],
};
const list = ['Francine', 'Eldon', 'Graziela'].map((name, index) => ({
  id: index + 1,
  meta: { sender: { name } },
}));
describe('conversation review order', () => {
  it('normalizes selected filter objects without losing numeric IDs', () => {
    const filters = normalizeReviewFilters([
      {
        attributeKey: 'inbox_id',
        filterOperator: 'equal_to',
        values: [{ id: 123, name: 'Inbox' }],
      },
    ]);
    expect(filters[0].values).toEqual([123]);
    expect(normalizeReviewFilters(filters)).toEqual(filters);
    expect(
      reviewConversationEligible(
        { ...list[0], inbox_id: 123 },
        { ...context, filters },
        1
      )
    ).toBe(true);
  });
  it('skips contacts that leave the native special views', () => {
    expect(
      reviewConversationEligible(
        { ...list[0], priority: null },
        { ...context, conversationType: 'priority' },
        1
      )
    ).toBe(false);
    expect(
      reviewConversationEligible(
        { ...list[0], last_non_activity_message: { message_type: 1 } },
        { ...context, conversationType: 'awaiting_reply' },
        1
      )
    ).toBe(false);
    expect(
      reviewConversationEligible(
        { ...list[0], first_reply_created_at: 1 },
        { ...context, conversationType: 'unattended' },
        1
      )
    ).toBe(false);
  });
  it('keeps Eldon next even when Francine or Eldon move to the top', () => {
    const point = createReviewPoint(list, list[0], context, 'Todos');
    const reordered = [list[1], list[2], list[0]];
    expect(point.remaining.map(item => item.name)).toEqual([
      'Eldon',
      'Graziela',
    ]);
    expect(reordered[0].id).toBe(point.remaining[0].id);
    expect(point.conversation_id).toBe(1);
  });
  it('separates tabs and filters', () => {
    expect(reviewViewKey(context)).not.toBe(
      reviewViewKey({ ...context, label: 'kelvin' })
    );
  });
  it('does not let an archived contact reappear in Todos', () => {
    expect(
      reviewConversationEligible(
        { ...list[0], labels: ['arquivado'] },
        context,
        1
      )
    ).toBe(false);
    expect(
      reviewConversationEligible(
        { ...list[0], labels: ['arquivado'] },
        { ...context, conversationType: 'archived' },
        1
      )
    ).toBe(true);
  });
  it('skips a contact whose saved label was removed', () => {
    expect(
      reviewConversationEligible(
        { ...list[0], labels: [] },
        { ...context, label: 'kelvin' },
        1
      )
    ).toBe(false);
  });
  it('checks assignment, status and inbox without changing messages', () => {
    expect(
      reviewConversationEligible(
        { ...list[0], inbox_id: 2, status: 'open' },
        { ...context, inboxId: 3 },
        1
      )
    ).toBe(false);
    expect(
      reviewConversationEligible(
        { ...list[0], status: 'resolved' },
        { ...context, status: 'open' },
        1
      )
    ).toBe(false);
    expect(
      reviewConversationEligible(list[0], { ...context, assigneeType: 'me' }, 1)
    ).toBe(false);
  });
  it('opens the original archived route instead of all conversations', () => {
    expect(
      reviewConversationPath(
        { context: { ...context, conversationType: 'archived' } },
        1,
        3
      )
    ).toBe('/app/accounts/1/archived/conversations/3');
  });
  it('bounds each snapshot and does not retain messages', () => {
    const long = Array.from({ length: 1000 }, (_, id) => ({
      id,
      messages: ['private'],
    }));
    const point = createReviewPoint(long, long[0], context, 'Todos');
    expect(point.remaining).toHaveLength(200);
    expect(JSON.stringify(point)).not.toContain('private');
  });
});
