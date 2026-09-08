import { getLiveMessageAction, isNearBottom } from '../liveMessageScrollHelper';

describe('live message scroll helper', () => {
  it('detects when the message panel is close enough to its end', () => {
    expect(
      isNearBottom({ scrollHeight: 1000, scrollTop: 820, clientHeight: 120 })
    ).toBe(true);
    expect(
      isNearBottom({ scrollHeight: 1000, scrollTop: 500, clientHeight: 120 })
    ).toBe(false);
  });

  it('scrolls automatically when a live message arrives at the end', () => {
    expect(
      getLiveMessageAction({
        newLength: 11,
        oldLength: 10,
        isLoadingPrevious: false,
        wasNearBottom: true,
      })
    ).toEqual({ type: 'scroll' });
  });

  it('notifies without moving the viewport when the operator reads history', () => {
    expect(
      getLiveMessageAction({
        newLength: 13,
        oldLength: 10,
        isLoadingPrevious: false,
        wasNearBottom: false,
      })
    ).toEqual({ type: 'notify', addedMessages: 3 });
  });

  it('ignores pagination and non-growing message collections', () => {
    expect(
      getLiveMessageAction({
        newLength: 12,
        oldLength: 10,
        isLoadingPrevious: true,
        wasNearBottom: false,
      })
    ).toEqual({ type: 'ignore' });
    expect(
      getLiveMessageAction({
        newLength: 10,
        oldLength: 10,
        isLoadingPrevious: false,
        wasNearBottom: true,
      })
    ).toEqual({ type: 'ignore' });
  });
});
