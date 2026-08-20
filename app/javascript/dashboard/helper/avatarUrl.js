/**
 * Active Storage's avatar_url is normally a 250px representation. When the
 * signed blob id is present, use the original blob for the profile preview.
 * Non-Active-Storage URLs are returned unchanged.
 */
export const getOriginalAvatarUrl = value => {
  if (!value) return '';

  try {
    const url = new URL(value, window.location.origin);
    const marker = '/rails/active_storage/representations/redirect/';
    const markerIndex = url.pathname.indexOf(marker);

    if (markerIndex === -1) return url.toString();

    const prefix = url.pathname.slice(0, markerIndex);
    const remainder = url.pathname.slice(markerIndex + marker.length);
    const [signedBlobId, , ...filenameParts] = remainder.split('/');
    const filename = filenameParts.join('/');

    if (!signedBlobId || !filename) return url.toString();

    url.pathname = `${prefix}/rails/active_storage/blobs/redirect/${signedBlobId}/${filename}`;
    return url.toString();
  } catch (error) {
    return value;
  }
};
