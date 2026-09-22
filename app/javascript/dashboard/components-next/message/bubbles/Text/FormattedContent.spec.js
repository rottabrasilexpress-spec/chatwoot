import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { describe, expect, it, vi } from 'vitest';
import FormattedContent from './FormattedContent.vue';

vi.mock('../../provider.js', () => ({
  useMessageContext: () => ({
    variant: ref('user'),
  }),
}));

describe('FormattedContent', () => {
  it('marks message content for scoped compact typography', () => {
    const wrapper = mount(FormattedContent, {
      props: { content: 'Linha 1\n\nLinha 2' },
      global: {
        directives: {
          dompurifyHtml: {
            beforeMount(element, binding) {
              element.innerHTML = binding.value;
            },
          },
        },
      },
    });

    expect(wrapper.classes()).toContain('rotta-message-content');
  });
});
