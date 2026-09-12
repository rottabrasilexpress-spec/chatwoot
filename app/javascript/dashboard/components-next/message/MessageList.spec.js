import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { describe, expect, it, vi } from 'vitest';
import MessageList from './MessageList.vue';

const MessageStub = {
  name: 'Message',
  props: ['deletedContentAvailable'],
  template: '<div data-test="message-stub" />',
};

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: key => {
    if (key === 'labels/getLabels') return ref([]);
    return ref(null);
  },
}));

describe('MessageList', () => {
  it('passes the retained deleted-content availability to each message', () => {
    const wrapper = mount(MessageList, {
      props: {
        currentUserId: 7,
        messages: [
          {
            id: 41,
            message_type: 0,
            created_at: 1_723_456_789,
            content: 'This message was deleted',
            content_attributes: { deleted: true },
            deleted_content_available: true,
          },
        ],
      },
      global: {
        stubs: { Message: MessageStub },
      },
    });

    expect(wrapper.get('[data-test="message-stub"]').exists()).toBe(true);
    expect(
      wrapper.findComponent(MessageStub).props('deletedContentAvailable')
    ).toBe(true);
  });
});
