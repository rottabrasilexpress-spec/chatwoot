import {
  conversationMatchesSearch,
  getConversationSearchResults,
} from '../conversationSearch';

describe('conversationMatchesSearch', () => {
  it('matches formatted WhatsApp numbers when the agent types only digits', () => {
    expect(
      conversationMatchesSearch(
        {
          contact: { name: 'Cliente', phone_number: '+55 (11) 96592-7865' },
        },
        '5511965927865'
      )
    ).toBe(true);
  });

  it('matches the WhatsApp source id when a contact has no phone field', () => {
    expect(
      conversationMatchesSearch(
        {
          contact: { name: 'Cliente' },
          contact_inbox: { source_id: '5511965927865@s.whatsapp.net' },
        },
        '11965927865'
      )
    ).toBe(true);
  });

  it('matches names without requiring accent marks or exact letter case', () => {
    expect(
      conversationMatchesSearch(
        { contact: { name: 'João da Silva' } },
        'joao DA'
      )
    ).toBe(true);
  });

  it('does not match a phone number from a short ambiguous digit query', () => {
    expect(
      conversationMatchesSearch(
        { contact: { name: 'Cliente', phone_number: '+55 (11) 96592-7865' } },
        '1234'
      )
    ).toBe(false);
  });

  it('keeps accent-insensitive local matches when the remote search returns none', () => {
    const localConversation = {
      id: 42,
      contact: { name: 'Heloisa Brizolari' },
    };

    expect(
      getConversationSearchResults({
        remoteResults: [],
        localResults: [localConversation],
        query: 'Heloísa Brizolari',
      })
    ).toEqual([localConversation]);
  });

  it('deduplicates conversations found in both remote and local results', () => {
    const remoteConversation = { id: 42, contact: { name: 'Tati Leal' } };
    const localConversation = { id: 42, contact: { name: 'Tati Leal' } };

    expect(
      getConversationSearchResults({
        remoteResults: [remoteConversation],
        localResults: [localConversation],
        query: 'Tati',
      })
    ).toEqual([remoteConversation]);
  });
});
