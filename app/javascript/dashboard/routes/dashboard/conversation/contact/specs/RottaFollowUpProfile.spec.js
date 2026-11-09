import { flushPromises, shallowMount } from '@vue/test-utils';
import RottaFollowUpProfile from '../RottaFollowUpProfile.vue';
import api from 'dashboard/api/rottaFollowUp';

vi.mock('dashboard/api/rottaFollowUp', () => ({
  default: { create: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: { template: '<div />' },
}));
vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: { template: '<button />' },
}));
vi.mock('dashboard/components-next/icon/Icon.vue', () => ({
  default: { template: '<span />' },
}));

describe('RottaFollowUpProfile request pressure', () => {
  let wrapper;
  beforeEach(() => {
    vi.useFakeTimers();
    api.create.mockReset();
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
  });
  afterEach(() => {
    wrapper?.unmount();
    vi.useRealTimers();
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
  });
  const mountProfile = () => {
    wrapper = shallowMount(RottaFollowUpProfile, {
      props: { conversationId: 206 },
    });
  };

  it('requests only the displayed conversation instead of the whole queue', async () => {
    api.create.mockResolvedValue({ data: { ok: true, jobs: [] } });
    mountProfile();
    await flushPromises();
    expect(api.create).toHaveBeenCalledWith({
      action: 'list',
      conversation_id: 206,
    });
  });

  it('does not overlap slow polls and coalesces the pending refresh', async () => {
    let finish;
    api.create.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          finish = resolve;
        })
    );
    api.create.mockResolvedValue({ data: { ok: true, jobs: [] } });
    mountProfile();
    await vi.advanceTimersByTimeAsync(15000);
    expect(api.create).toHaveBeenCalledTimes(1);
    finish({ data: { ok: true, jobs: [] } });
    await flushPromises();
    expect(api.create).toHaveBeenCalledTimes(2);
  });

  it('suspends hidden-tab reads and refreshes on return', async () => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
    api.create.mockResolvedValue({ data: { ok: true, jobs: [] } });
    mountProfile();
    await vi.advanceTimersByTimeAsync(15000);
    expect(api.create).not.toHaveBeenCalled();
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
    document.dispatchEvent(new Event('visibilitychange'));
    await flushPromises();
    expect(api.create).toHaveBeenCalledTimes(1);
  });

  it('fetches the latest conversation after an in-flight conversation changes', async () => {
    let finish;
    api.create.mockImplementationOnce(
      () =>
        new Promise(resolve => {
          finish = resolve;
        })
    );
    api.create.mockResolvedValue({ data: { ok: true, jobs: [] } });
    mountProfile();
    await wrapper.setProps({ conversationId: 2143 });
    finish({ data: { ok: true, jobs: [] } });
    await flushPromises();
    expect(api.create).toHaveBeenLastCalledWith({
      action: 'list',
      conversation_id: 2143,
    });
  });
});
