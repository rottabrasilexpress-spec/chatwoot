export const isNearBottom = (element, threshold = 96) => {
  if (!element) return true;

  const distanceFromBottom =
    element.scrollHeight - element.scrollTop - element.clientHeight;

  return distanceFromBottom <= threshold;
};

export const getLiveMessageAction = ({
  newLength,
  oldLength,
  isLoadingPrevious,
  wasNearBottom,
}) => {
  if (
    !Number.isFinite(newLength) ||
    !Number.isFinite(oldLength) ||
    newLength <= oldLength ||
    isLoadingPrevious
  ) {
    return { type: 'ignore' };
  }

  if (wasNearBottom) return { type: 'scroll' };

  return {
    type: 'notify',
    addedMessages: newLength - oldLength,
  };
};
