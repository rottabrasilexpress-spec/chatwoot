import {
  beginConversationLabelMutation,
  isLatestConversationLabelMutation,
  withIdempotentConversationLabelMutation,
  withConversationLabelMutationLock,
} from '../conversationLabelMutationQueue';

describe('conversation label mutation queue', () => {
  it('serializes rapid mutations for the same conversation', async () => {
    const events = [];
    let releaseFirst;
    const firstGate = new Promise(resolve => {
      releaseFirst = resolve;
    });
    const first = withConversationLabelMutationLock([9001], async () => {
      events.push('first:start');
      await firstGate;
      events.push('first:finish');
    });
    const second = withConversationLabelMutationLock([9001], () => {
      events.push('second');
    });

    await vi.waitFor(() => expect(events).toEqual(['first:start']));
    releaseFirst();
    await Promise.all([first, second]);

    expect(events).toEqual(['first:start', 'first:finish', 'second']);
  });

  it('does not serialize independent conversations and detects stale intent', async () => {
    const firstVersion = beginConversationLabelMutation([9002]);
    const latestVersion = beginConversationLabelMutation([9002]);
    const completed = [];

    await Promise.all([
      withConversationLabelMutationLock([9002], () => completed.push('same-1')),
      withConversationLabelMutationLock([9003], () => completed.push('other')),
      withConversationLabelMutationLock([9002], () => completed.push('same-2')),
    ]);

    expect(completed).toEqual(['same-1', 'other', 'same-2']);
    expect(isLatestConversationLabelMutation(9002, firstVersion)).toBe(false);
    expect(isLatestConversationLabelMutation(9002, latestVersion)).toBe(true);
  });

  it('shares one in-flight operation for identical quick label actions', async () => {
    let release;
    const gate = new Promise(resolve => {
      release = resolve;
    });
    const operation = vi.fn(async () => {
      await gate;
      return { status: 'success' };
    });

    const first = withIdempotentConversationLabelMutation(
      [9004],
      'set:emitir-contrato',
      operation
    );
    const second = withIdempotentConversationLabelMutation(
      [9004],
      'set:emitir-contrato',
      operation
    );
    release();

    await expect(Promise.all([first, second])).resolves.toEqual([
      { status: 'success' },
      { status: 'success' },
    ]);
    expect(operation).toHaveBeenCalledTimes(1);
  });
});
