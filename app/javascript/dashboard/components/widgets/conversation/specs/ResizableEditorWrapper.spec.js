import { mount } from '@vue/test-utils';
import ResizableEditorWrapper from '../ResizableEditorWrapper.vue';

describe('ResizableEditorWrapper', () => {
  it('starts with a compact WhatsApp-sized editor and can expand and shrink again', async () => {
    const wrapper = mount(ResizableEditorWrapper, {
      props: { containerHeight: 900 },
      slots: { default: '<div />' },
    });

    expect(wrapper.attributes('style')).toContain('--editor-height: 72px');
    expect(wrapper.attributes('style')).toContain('--editor-min-allowed: 64px');

    wrapper.vm.toggleEditorExpand();
    await wrapper.vm.$nextTick();
    expect(wrapper.attributes('style')).not.toContain('--editor-height: 72px');

    wrapper.vm.toggleEditorExpand();
    await wrapper.vm.$nextTick();
    expect(wrapper.attributes('style')).toContain('--editor-height: 72px');
  });
});
