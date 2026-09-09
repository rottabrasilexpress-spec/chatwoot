export const CHATWOOT_ATTACHMENT_DRAG_TYPE =
  'application/x-chatwoot-attachment';

export const setAttachmentDragData = (dataTransfer, attachment) => {
  if (
    !dataTransfer ||
    attachment?.id === undefined ||
    attachment?.id === null
  ) {
    return false;
  }

  try {
    dataTransfer.effectAllowed = 'copy';
    dataTransfer.setData(
      CHATWOOT_ATTACHMENT_DRAG_TYPE,
      JSON.stringify({ id: attachment.id })
    );
    return true;
  } catch (error) {
    return false;
  }
};

export const parseAttachmentDragData = dataTransfer => {
  if (!dataTransfer?.getData) return null;

  try {
    const value = dataTransfer.getData(CHATWOOT_ATTACHMENT_DRAG_TYPE);
    if (!value) return null;

    const payload = JSON.parse(value);
    return payload?.id === undefined || payload?.id === null ? null : payload;
  } catch (error) {
    return null;
  }
};
