export const canViewCalculator = ({ shared, ownerId, currentUserId }) => {
  if (ownerId === null || ownerId === undefined) return true;
  return Boolean(shared) || Number(ownerId) === Number(currentUserId);
};

export const shouldClaimCalculatorOwnership = ({ ownerId, currentUserId }) =>
  (ownerId === null || ownerId === undefined) && Boolean(currentUserId);
