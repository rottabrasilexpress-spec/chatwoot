import { flushPromises, mount } from '@vue/test-utils';

import SharedFiles from '../SharedFiles.vue';

const mocks = vi.hoisted(() => ({
  allAttachments: { value: [] },
  attachmentsLoaded: { value: true },
  downloadFile: vi.fn(),
  alert: vi.fn(),
}));

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key => {
    if (key === 'getSelectedChatAttachments') return mocks.allAttachments;
    return mocks.attachmentsLoaded;
  },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: mocks.alert,
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('@chatwoot/utils', () => ({
  downloadFile: mocks.downloadFile,
}));

vi.mock(
  'dashboard/components/widgets/conversation/components/GalleryView.vue',
  () => ({
    default: { template: '<div data-testid="gallery" />' },
  })
);

const global = {
  stubs: {
    Media: { template: '<div data-testid="media" />' },
    Files: { template: '<div data-testid="files" />' },
    Spinner: { template: '<div data-testid="spinner" />' },
    GalleryView: { template: '<div data-testid="gallery" />' },
  },
};

const attachment = {
  id: 42,
  data_url: 'https://cdn.example.test/document.pdf',
  file_type: 'application/pdf',
  extension: 'pdf',
};

const createWrapper = () => mount(SharedFiles, { global });

describe('SharedFiles', () => {
  beforeEach(() => {
    mocks.allAttachments.value = [];
    mocks.attachmentsLoaded.value = true;
    mocks.downloadFile.mockReset();
    mocks.alert.mockReset();
  });

  it('keeps only a safe attachment drop area when there are no messages with files', () => {
    const wrapper = createWrapper();

    expect(wrapper.find('[data-testid="attachments-dropzone"]').exists()).toBe(
      true
    );
    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.text()).toContain('Arraste anexos recebidos aqui');
  });

  it('downloads an existing conversation attachment dropped on the area', async () => {
    mocks.allAttachments.value = [attachment];
    const wrapper = createWrapper();
    const dataTransfer = {
      files: [],
      getData: vi.fn(() => JSON.stringify({ id: attachment.id })),
    };

    await wrapper
      .find('[data-testid="attachments-dropzone"]')
      .trigger('drop', { dataTransfer });
    await flushPromises();

    expect(mocks.downloadFile).toHaveBeenCalledWith({
      url: attachment.data_url,
      type: attachment.file_type,
      extension: attachment.extension,
    });
    expect(mocks.alert).not.toHaveBeenCalled();
    expect(wrapper.find('[aria-live="polite"]').text()).toContain('salvo');
  });

  it('rejects local files and only accepts existing conversation attachments', async () => {
    const file = new File(['content'], 'invoice.pdf', {
      type: 'application/pdf',
    });
    const wrapper = createWrapper();

    await wrapper
      .find('[data-testid="attachments-dropzone"]')
      .trigger('drop', { dataTransfer: { files: [file], getData: () => '' } });
    await flushPromises();

    expect(mocks.downloadFile).not.toHaveBeenCalled();
    expect(mocks.alert).toHaveBeenCalledWith(
      'Não foi possível salvar o anexo recebido.'
    );
    expect(wrapper.find('[aria-live="polite"]').text()).toContain(
      'Não foi possível'
    );
  });

  it('reports an invalid drop and does not touch the conversation', async () => {
    const wrapper = createWrapper();

    await wrapper
      .find('[data-testid="attachments-dropzone"]')
      .trigger('drop', { dataTransfer: { files: [], getData: () => '' } });

    expect(mocks.downloadFile).not.toHaveBeenCalled();
    expect(mocks.alert).toHaveBeenCalledWith(
      'Não foi possível salvar o anexo recebido.'
    );
    expect(wrapper.find('[aria-live="polite"]').text()).toContain(
      'Não foi possível'
    );
  });
});
