import { createStore } from 'vuex';
import types from 'dashboard/store/mutation-types';
import {
  applyConversationReadState,
  subscribeToConversationReadState,
} from '../conversationReadState';

describe('shared unread state in search cards', () => {
  const card = { id: 42, unread_count: 1, labels: ['kelvin'] };

  it.each([0, 2])(
    'updates only read state (%s), preserving ranking/details',
    unreadCount => {
      const anotherCard = { id: 43, unread_count: 3 };
      const source = [card, anotherCard];
      const result = applyConversationReadState(source, {
        id: 42,
        unread_count: unreadCount,
        agent_last_seen_at: 123,
        labels: [],
      });
      expect(result[0]).toEqual({
        ...card,
        unread_count: unreadCount,
        agent_last_seen_at: 123,
      });
      expect(result[1]).toBe(anotherCard);
      expect(source[0].unread_count).toBe(1);
    }
  );

  it('does no work without an active search', () => {
    expect(applyConversationReadState(null, { id: 42, unread_count: 0 })).toBe(
      null
    );
  });

  it('does not re-render cards for other conversations or unchanged counts', () => {
    const source = [card];
    expect(
      applyConversationReadState(source, { id: 99, unread_count: 0 })
    ).toBe(source);
    expect(
      applyConversationReadState(source, { id: 42, unread_count: 1 })
    ).toBe(source);
  });

  it.each([
    [types.UPDATE_MESSAGE_UNREAD_COUNT, { id: 42, lastSeen: 123 }, 0],
    [types.UPDATE_MESSAGE_UNREAD_COUNT, { id: 42, unreadCount: 2 }, 2],
    [types.UPDATE_CONVERSATION, { id: 42, unread_count: 0 }, 0],
    [
      types.ADD_MESSAGE,
      {
        conversation_id: 42,
        message_type: 0,
        conversation: { unread_count: 2 },
      },
      2,
    ],
    [
      types.ADD_MESSAGE,
      {
        conversation_id: 42,
        message_type: 1,
        conversation: { unread_count: 2 },
      },
      2,
    ],
  ])(
    'uses confirmed %s mutations without additional requests',
    (type, payload, unreadCount) => {
      const store = createStore({ mutations: { [type]: vi.fn() } });
      const onReadState = vi.fn();
      const unsubscribe = subscribeToConversationReadState(store, onReadState);
      store.commit(type, payload);
      expect(onReadState).toHaveBeenCalledWith(
        expect.objectContaining({ id: 42, unread_count: unreadCount })
      );
      unsubscribe();
      store.commit(type, payload);
      expect(onReadState).toHaveBeenCalledTimes(1);
    }
  );

  it.each([
    [types.ADD_MESSAGE, { conversation_id: 42, status: 'pending' }],
    [types.UPDATE_CONVERSATION, { id: 42, labels: ['kelvin'] }],
    [types.SET_LIST_LOADING_STATUS, {}],
  ])('ignores partial/unrelated %s mutations', (type, payload) => {
    const store = createStore({ mutations: { [type]: vi.fn() } });
    const onReadState = vi.fn();
    const unsubscribe = subscribeToConversationReadState(store, onReadState);
    store.commit(type, payload);
    expect(onReadState).not.toHaveBeenCalled();
    unsubscribe();
  });
});
