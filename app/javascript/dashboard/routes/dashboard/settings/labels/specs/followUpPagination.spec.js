import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { createI18n } from 'vue-i18n';
import reportMessages from 'dashboard/i18n/locale/en/report.json';
import reviewMessages from 'dashboard/i18n/locale/en/yearInReview.json';
import FollowUp from '../FollowUp.vue';
import FollowUpPagination from '../FollowUpPagination.vue';
import api from 'dashboard/api/rottaFollowUp';

vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));
vi.mock('dashboard/api/rottaFollowUp', () => ({
  default: { create: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings: ref({}), updateUISettings: vi.fn() }),
}));
vi.mock('../../components/BaseSettingsHeader.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('../../SettingsLayout.vue', () => ({
  default: {
    template: '<div><slot name="header" /><slot name="body" /><slot /></div>',
  },
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: {
    props: ['label', 'disabled'],
    template: '<button :disabled="disabled"><slot />{{ label }}</button>',
  },
}));
vi.mock('dashboard/components-next/icon/Icon.vue', () => ({
  default: { template: '<i />' },
}));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: { template: '<div />' },
}));

describe('follow-up paginated requests', () => {
  let wrapper;
  const appOptions = {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'en',
          messages: { en: { ...reportMessages, ...reviewMessages } },
        }),
      ],
      directives: { tooltip: () => {} },
    },
  };
  beforeEach(() => {
    api.create.mockReset();
    api.create.mockImplementation(async query => ({
      data: {
        ok: true,
        jobs: [],
        labels: {},
        pagination: {
          page: query.page,
          per_page: 25,
          total: 2000,
          total_pages: 80,
        },
        panel_jobs: [],
        panel_pagination: {
          page: query.panel_page,
          per_page: 25,
          total: 3,
          total_pages: 1,
        },
        summary: {
          all: 2000,
          today: 100,
          overdue: 20,
          failures: 3,
          counts: {},
          views: { all: 2000, contact: 1000, budget: 1000 },
        },
      },
    }));
  });
  afterEach(() => wrapper?.unmount());

  it('requests a bounded page instead of the entire queue', async () => {
    wrapper = mount(FollowUp, appOptions);
    await flushPromises();
    expect(api.create).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'list', page: 1, per_page: 25 })
    );
  });

  it('keeps global totals independent from the records on the current page', async () => {
    wrapper = mount(FollowUp, appOptions);
    await flushPromises();
    expect(
      wrapper.get('[aria-label="Mostrar todos os follow-ups ativos"]').text()
    ).toContain('2000');
  });

  it('navigates pages and preserves global totals', async () => {
    wrapper = mount(FollowUp, appOptions);
    await flushPromises();
    wrapper.findComponent(FollowUpPagination).vm.$emit('page', 2);
    await new Promise(resolve => {
      setTimeout(resolve, 500);
    });
    await flushPromises();
    expect(api.create).toHaveBeenLastCalledWith(
      expect.objectContaining({ page: 2 })
    );
    expect(
      wrapper.get('[aria-label="Mostrar todos os follow-ups ativos"]').text()
    ).toContain('2000');
  });

  it('opens the globally counted failures panel without a rendering error', async () => {
    wrapper = mount(FollowUp, appOptions);
    await flushPromises();
    await wrapper
      .get('[aria-label="Mostrar falhas do follow-up"]')
      .trigger('click');
    await new Promise(resolve => {
      setTimeout(resolve, 500);
    });
    await flushPromises();
    expect(api.create).toHaveBeenLastCalledWith(
      expect.objectContaining({ panel: 'failures', panel_page: 1 })
    );
    expect(wrapper.text()).toContain('Falhas de follow-up');
  });

  it('shows a request failure instead of an empty successful queue', async () => {
    api.create.mockRejectedValue(new Error('upstream unavailable'));
    wrapper = mount(FollowUp, appOptions);
    await flushPromises();
    expect(wrapper.get('[role="alert"]').text()).toContain(
      'Não foi possível atualizar'
    );
    expect(wrapper.text()).not.toContain('Nenhum follow-up nesta visão');
  });

  it('disables previous and next at the respective boundaries', async () => {
    wrapper = mount(FollowUpPagination, {
      ...appOptions,
      props: {
        label: 'Pages',
        pagination: { page: 1, per_page: 25, total: 26, total_pages: 2 },
      },
    });
    expect(wrapper.findAll('button')[0].attributes('disabled')).toBeDefined();
    await wrapper.findAll('button')[1].trigger('click');
    expect(wrapper.emitted('page')).toEqual([[2]]);
    await wrapper.setProps({
      pagination: { page: 2, per_page: 25, total: 26, total_pages: 2 },
    });
    expect(wrapper.findAll('button')[1].attributes('disabled')).toBeDefined();
  });
});
