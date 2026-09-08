import { INBOX_TYPES, isVoiceCallEnabled } from 'dashboard/helper/inbox';

export const INBOX_FEATURES = {
  REPLY_TO: 'replyTo',
  REPLY_TO_OUTGOING: 'replyToOutgoing',
};

export const isRottaReplyInbox = (channelType, inboxId = null) => {
  const normalizedChannelType = String(channelType || '').toLowerCase();
  // Rotta's UAZAPI overlay can persist the synthetic inbox as id 0. In that
  // case the inbox record is not available to the frontend, so the channel
  // type alone cannot advertise reply support.
  const isSyntheticRottaInbox =
    inboxId !== null &&
    inboxId !== undefined &&
    Number(inboxId) === 0 &&
    !normalizedChannelType.includes('email');

  return (
    [INBOX_TYPES.API, INBOX_TYPES.WHATSAPP].includes(channelType) ||
    normalizedChannelType.includes('uazapi') ||
    isSyntheticRottaInbox
  );
};

// This is a single source of truth for inbox features
// This is used to check if a feature is available for a particular inbox or not
export const INBOX_FEATURE_MAP = {
  [INBOX_FEATURES.REPLY_TO]: [
    INBOX_TYPES.FB,
    INBOX_TYPES.WEB,
    INBOX_TYPES.TWITTER,
    INBOX_TYPES.WHATSAPP,
    INBOX_TYPES.TELEGRAM,
    INBOX_TYPES.TIKTOK,
    INBOX_TYPES.API,
  ],
  [INBOX_FEATURES.REPLY_TO_OUTGOING]: [
    INBOX_TYPES.WEB,
    INBOX_TYPES.TWITTER,
    INBOX_TYPES.WHATSAPP,
    INBOX_TYPES.TELEGRAM,
    INBOX_TYPES.TIKTOK,
    INBOX_TYPES.API,
  ],
};

export default {
  computed: {
    channelType() {
      return this.inbox.channel_type;
    },
    whatsAppAPIProvider() {
      return this.inbox.provider || '';
    },
    isAMicrosoftInbox() {
      return this.isAnEmailChannel && this.inbox.provider === 'microsoft';
    },
    isAGoogleInbox() {
      return this.isAnEmailChannel && this.inbox.provider === 'google';
    },
    isAPIInbox() {
      return this.channelType === INBOX_TYPES.API;
    },
    isATwitterInbox() {
      return this.channelType === INBOX_TYPES.TWITTER;
    },
    isAFacebookInbox() {
      return this.channelType === INBOX_TYPES.FB;
    },
    isAWebWidgetInbox() {
      return this.channelType === INBOX_TYPES.WEB;
    },
    isATwilioChannel() {
      return this.channelType === INBOX_TYPES.TWILIO;
    },
    isALineChannel() {
      return this.channelType === INBOX_TYPES.LINE;
    },
    voiceCallEnabled() {
      return isVoiceCallEnabled(this.inbox);
    },
    isAnEmailChannel() {
      return this.channelType === INBOX_TYPES.EMAIL;
    },
    isATelegramChannel() {
      return this.channelType === INBOX_TYPES.TELEGRAM;
    },
    isATwilioSMSChannel() {
      const { medium: medium = '' } = this.inbox;
      return this.isATwilioChannel && medium === 'sms';
    },
    isASmsInbox() {
      return this.channelType === INBOX_TYPES.SMS || this.isATwilioSMSChannel;
    },
    isATwilioWhatsAppChannel() {
      const { medium: medium = '' } = this.inbox;
      return this.isATwilioChannel && medium === 'whatsapp';
    },
    isAWhatsAppCloudChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP &&
        this.whatsAppAPIProvider === 'whatsapp_cloud'
      );
    },
    is360DialogWhatsAppChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP &&
        this.whatsAppAPIProvider === 'default'
      );
    },
    chatAdditionalAttributes() {
      const { additional_attributes: additionalAttributes } = this.chat || {};
      return additionalAttributes || {};
    },
    isTwitterInboxTweet() {
      return this.chatAdditionalAttributes.type === 'tweet';
    },
    twilioBadge() {
      return `${this.isATwilioSMSChannel ? 'sms' : 'whatsapp'}`;
    },
    twitterBadge() {
      return `${this.isTwitterInboxTweet ? 'twitter-tweet' : 'twitter-dm'}`;
    },
    facebookBadge() {
      return this.chatAdditionalAttributes.type || 'facebook';
    },
    inboxBadge() {
      let badgeKey = '';
      if (this.isATwitterInbox) {
        badgeKey = this.twitterBadge;
      } else if (this.isAFacebookInbox) {
        badgeKey = this.facebookBadge;
      } else if (this.isATwilioChannel) {
        badgeKey = this.twilioBadge;
      } else if (this.isAWhatsAppChannel) {
        badgeKey = 'whatsapp';
      } else if (this.isATiktokChannel) {
        badgeKey = 'tiktok';
      }
      return badgeKey || this.channelType;
    },
    isAWhatsAppChannel() {
      return (
        this.channelType === INBOX_TYPES.WHATSAPP ||
        this.isATwilioWhatsAppChannel
      );
    },
    isAnInstagramChannel() {
      return this.channelType === INBOX_TYPES.INSTAGRAM;
    },
    isATiktokChannel() {
      return this.channelType === INBOX_TYPES.TIKTOK;
    },
  },
  methods: {
    inboxHasFeature(feature) {
      if (
        [INBOX_FEATURES.REPLY_TO, INBOX_FEATURES.REPLY_TO_OUTGOING].includes(
          feature
        ) &&
        isRottaReplyInbox(this.channelType)
      ) {
        return true;
      }

      return INBOX_FEATURE_MAP[feature]?.includes(this.channelType) ?? false;
    },
  },
};
