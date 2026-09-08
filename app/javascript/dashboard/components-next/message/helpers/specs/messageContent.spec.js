import { describe, expect, it } from 'vitest';
import { getMessageDisplayContent } from '../messageContent';

describe('messageContent', () => {
  it('keeps the reaction emoji and removes the provider label', () => {
    expect(getMessageDisplayContent('🥰 [ reação ]')).toBe('🥰');
    expect(getMessageDisplayContent('👍 [reaction]')).toBe('👍');
  });

  it('hides a media-only provider placeholder when an attachment exists', () => {
    expect(getMessageDisplayContent('[image]', [{ file_type: 'image' }])).toBe(
      ''
    );
    expect(getMessageDisplayContent('[audio]', [{ fileType: 'audio' }])).toBe(
      ''
    );
  });

  it('preserves a caption that contains a media token', () => {
    expect(
      getMessageDisplayContent('[image] veja a foto', [{ file_type: 'image' }])
    ).toBe('[image] veja a foto');
  });
});
