export const canViewCalculator = ({ shared, ownerId, currentUserId }) => {
  if (ownerId === null || ownerId === undefined) return true;
  return Boolean(shared) || Number(ownerId) === Number(currentUserId);
};

export const shouldClaimCalculatorOwnership = ({ ownerId, currentUserId }) =>
  (ownerId === null || ownerId === undefined) && Boolean(currentUserId);

// The shared Switch component emits the value it had before the click. Keep
// this conversion in one place so the visibility flow never persists the
// opposite of what the agent selected.
export const getRequestedCalculatorVisibility = switchEventValue =>
  switchEventValue !== true;
