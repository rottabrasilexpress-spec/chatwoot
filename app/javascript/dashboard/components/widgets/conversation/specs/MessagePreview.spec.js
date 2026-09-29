import { shallowMount } from '@vue/test-utils';
import MessagePreview from '../MessagePreview.vue';

const mountPreview = messageType =>
  shallowMount(MessagePreview, {
    props: {
      message: {
        message_type: messageType,
        content: 'Mensagem de teste',
        attachments: [],
      },
    },
    global: {
      mocks: { $t: key => key },
      stubs: { 'fluent-icon': true },
    },
  });

describe('MessagePreview', () => {
  it('identifies the latest outbound reply from the team', () => {
    const wrapper = mountPreview(1);

    expect(wrapper.text()).toContain('CONVERSATION.LAST_REPLY_FROM_TEAM');
  });

  it('does not mark an incoming customer message as a team reply', () => {
    const wrapper = mountPreview(0);

    expect(wrapper.text()).not.toContain('CONVERSATION.LAST_REPLY_FROM_TEAM');
  });
});
