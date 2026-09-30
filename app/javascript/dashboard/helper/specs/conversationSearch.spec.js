import {
  conversationMatchesSearch,
  getConversationSearchResults,
  getSearchConversationDestination,
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

  it('keeps authoritative typo suggestions from the server', () => {
    const match = { id: 2143, meta: { sender: { name: 'Kelvin Martins' } } };
    expect(
      getConversationSearchResults({ remoteResults: [match], query: 'Kelvn' })
    ).toEqual([match]);
  });

  it('does not confuse a label with the customer name', () => {
    expect(
      conversationMatchesSearch(
        { contact: { name: 'Amanda' }, labels: ['kelvin'] },
        'Kelvin'
      )
    ).toBe(false);
  });

  it('finds partial phone numbers as they are typed', () => {
    expect(
      conversationMatchesSearch(
        { contact: { phone_number: '+55 (11) 96592-7865' } },
        '1196'
      )
    ).toBe(true);
  });
});

describe('search result destination only', () => {
  it('prioritizes archived over any label', () => {
    expect(
      getSearchConversationDestination({
        labels: ['kelvin', 'arquivado', 'finalizados'],
      })
    ).toEqual({ conversationType: 'archived' });
  });
  it('recognizes archived conversations by authoritative status', () => {
    expect(
      getSearchConversationDestination({
        status: 'resolved',
        labels: ['kelvin'],
      })
    ).toEqual({ conversationType: 'archived' });
  });
  it.each([
    [['kelvin', 'finalizados'], 'finalizados'],
    [['caio-atencao', 'clientes-fechados'], 'clientes-fechados'],
    [['kelvin', 'caio-atencao', 'emitir-contrato'], 'emitir-contrato'],
    [['kelvin', 'caio-atencao'], 'caio-atencao'],
    [['kelvin'], 'kelvin'],
  ])('uses the approved priority for %j', (labels, label) => {
    expect(getSearchConversationDestination({ labels })).toEqual({ label });
  });
  it('uses the main conversation route when no special label applies', () => {
    expect(
      getSearchConversationDestination({ labels: ['primeiro-contato'] })
    ).toEqual({});
  });
});
