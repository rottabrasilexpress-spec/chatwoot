import {
  CHATWOOT_ATTACHMENT_DRAG_TYPE,
  parseAttachmentDragData,
  setAttachmentDragData,
} from '../attachmentDrag';

describe('attachment drag payload', () => {
  it('writes a copy-only payload containing the attachment id', () => {
    const dataTransfer = { setData: vi.fn() };

    expect(setAttachmentDragData(dataTransfer, { id: 42 })).toBe(true);
    expect(dataTransfer.effectAllowed).toBe('copy');
    expect(dataTransfer.setData).toHaveBeenCalledWith(
      CHATWOOT_ATTACHMENT_DRAG_TYPE,
      JSON.stringify({ id: 42 })
    );
  });

  it('accepts only a valid attachment payload', () => {
    expect(
      parseAttachmentDragData({
        getData: () => JSON.stringify({ id: 42 }),
      })
    ).toEqual({ id: 42 });
    expect(parseAttachmentDragData({ getData: () => '{invalid' })).toBeNull();
    expect(parseAttachmentDragData({ getData: () => '' })).toBeNull();
  });
});
