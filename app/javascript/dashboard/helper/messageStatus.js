import { MESSAGE_STATUS } from 'dashboard/components-next/message/constants';

const providerStatusKeys = [
  'uazapi_status',
  'uazapiStatus',
  'ack',
  'ack_status',
  'ackStatus',
  'message_status',
  'messageStatus',
];

const statusRank = {
  [MESSAGE_STATUS.SENT]: 0,
  [MESSAGE_STATUS.DELIVERED]: 1,
  [MESSAGE_STATUS.READ]: 2,
};

export const normalizeProviderMessageStatus = value => {
  const normalized = String(value ?? '')
    .trim()
    .toLowerCase();
  if (!normalized) return '';

  if (['0', '1', '2'].includes(normalized)) return MESSAGE_STATUS.SENT;
  if (normalized === '3') return MESSAGE_STATUS.DELIVERED;
  if (['4', '5'].includes(normalized)) return MESSAGE_STATUS.READ;

  if (normalized === MESSAGE_STATUS.SENT) return MESSAGE_STATUS.SENT;
  if (normalized === MESSAGE_STATUS.DELIVERED) return MESSAGE_STATUS.DELIVERED;
  if (normalized === MESSAGE_STATUS.READ) return MESSAGE_STATUS.READ;
  if (normalized === MESSAGE_STATUS.FAILED) return MESSAGE_STATUS.FAILED;

  if (
    normalized.includes('read') ||
    normalized.includes('seen') ||
    normalized.includes('played')
  ) {
    return MESSAGE_STATUS.READ;
  }
  if (
    normalized.includes('deliver') ||
    normalized.includes('delivery') ||
    normalized.includes('server_ack')
  ) {
    return MESSAGE_STATUS.DELIVERED;
  }
  if (
    normalized.includes('fail') ||
    normalized.includes('error') ||
    normalized.includes('cancel')
  ) {
    return MESSAGE_STATUS.FAILED;
  }

  return '';
};

export const getMessageDeliveryStatus = message => {
  if (!message) return '';

  const additionalAttributes = message.additional_attributes || {};
  const contentAttributes = message.content_attributes || {};
  const providerValues = [
    ...providerStatusKeys.map(key => additionalAttributes[key]),
    ...providerStatusKeys.map(key => contentAttributes[key]),
  ];

  const statuses = [...providerValues, message.status]
    .map(normalizeProviderMessageStatus)
    .filter(Boolean);

  if (statuses.includes(MESSAGE_STATUS.FAILED)) {
    return MESSAGE_STATUS.FAILED;
  }

  return statuses.reduce((highest, candidate) => {
    if (!highest) return candidate;
    return statusRank[candidate] > statusRank[highest] ? candidate : highest;
  }, '');
};
