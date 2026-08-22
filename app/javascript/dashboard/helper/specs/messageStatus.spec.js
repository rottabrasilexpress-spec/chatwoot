import {
  getMessageDeliveryStatus,
  normalizeProviderMessageStatus,
} from '../messageStatus';

describe('messageStatus', () => {
  it('maps Uazapi ACK values to WhatsApp delivery states', () => {
    expect(normalizeProviderMessageStatus(1)).toBe('sent');
    expect(normalizeProviderMessageStatus(2)).toBe('sent');
    expect(normalizeProviderMessageStatus(3)).toBe('delivered');
    expect(normalizeProviderMessageStatus(4)).toBe('read');
    expect(normalizeProviderMessageStatus(5)).toBe('read');
  });

  it('uses the provider status stored by the webhook before the local status', () => {
    expect(
      getMessageDeliveryStatus({
        status: 'sent',
        additional_attributes: { uazapi_status: 3 },
      })
    ).toBe('delivered');
  });

  it('does not expose a status for unknown provider values', () => {
    expect(normalizeProviderMessageStatus('unknown')).toBe('');
  });
});
