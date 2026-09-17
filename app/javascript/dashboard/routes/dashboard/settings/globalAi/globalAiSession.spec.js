import { describe, expect, it } from 'vitest';
import {
  buildGlobalAiViewState,
  parseStoredGlobalAiThreadId,
} from './globalAiSession';

describe('globalAiSession', () => {
  it('restores only the thread identifier from session storage', () => {
    expect(
      parseStoredGlobalAiThreadId(
        JSON.stringify({
          threadId: 42,
          messages: [{ role: 'assistant', content: 'resposta antiga' }],
          resultCards: [{ conversation_id: 1 }],
        })
      )
    ).toBe(42);
  });

  it('rebuilds messages and cards exclusively from the authoritative server thread', () => {
    expect(
      buildGlobalAiViewState({
        id: 42,
        messages: [
          {
            message_type: 'user',
            message: { content: 'Quem está pendente?' },
          },
          {
            message_type: 'assistant',
            message: {
              answer: 'Há um cliente pendente.',
              cards: [{ conversation_id: 2165 }],
            },
          },
        ],
      })
    ).toEqual({
      threadId: 42,
      messages: [
        { role: 'user', content: 'Quem está pendente?' },
        { role: 'assistant', content: 'Há um cliente pendente.' },
      ],
      resultCards: [{ conversation_id: 2165 }],
    });
  });
});
