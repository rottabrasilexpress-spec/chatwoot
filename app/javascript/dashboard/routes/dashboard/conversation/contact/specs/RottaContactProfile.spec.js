import { mount } from '@vue/test-utils';

import RottaContactProfile from '../RottaContactProfile.vue';

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({ value: [] }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('@chatwoot/utils', () => ({
  downloadFile: vi.fn(),
}));

vi.mock(
  'dashboard/components/widgets/conversation/components/GalleryView.vue',
  () => ({
    default: { template: '<div data-testid="gallery" />' },
  })
);

describe('RottaContactProfile', () => {
  it('renders the shared attachments area without operational profile fields', () => {
    const wrapper = mount(RottaContactProfile, {
      global: {
        stubs: {
          SharedFiles: { template: '<div data-testid="shared-files" />' },
        },
      },
    });

    expect(wrapper.text()).toContain('Anexos');
    expect(wrapper.find('[data-testid="shared-files"]').exists()).toBe(true);
    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.find('input').exists()).toBe(false);
    expect(wrapper.find('textarea').exists()).toBe(false);
  });
});
