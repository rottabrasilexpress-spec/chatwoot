/* global axios */
const pending = new Map();

// These sidebar reads have identical URL, authentication and response shape.
// Share only requests still in flight; the next read always reaches the server.
export const coalescedGet = url => {
  if (!pending.has(url)) {
    const request = axios.get(url).finally(() => pending.delete(url));
    pending.set(url, request);
  }
  return pending.get(url);
};
