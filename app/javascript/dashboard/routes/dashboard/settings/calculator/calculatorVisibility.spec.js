import { canViewCalculator } from './calculatorVisibility';

describe('calculatorVisibility', () => {
  it('keeps the calculator available until its owner is established', () => {
    expect(
      canViewCalculator({ shared: false, ownerId: null, currentUserId: 4 })
    ).toBe(true);
  });

  it('shows a private calculator only to its owner', () => {
    expect(
      canViewCalculator({ shared: false, ownerId: 4, currentUserId: 4 })
    ).toBe(true);
    expect(
      canViewCalculator({ shared: false, ownerId: 4, currentUserId: 9 })
    ).toBe(false);
  });

  it('shows a shared calculator to another agent', () => {
    expect(
      canViewCalculator({ shared: true, ownerId: 4, currentUserId: 9 })
    ).toBe(true);
  });
});
