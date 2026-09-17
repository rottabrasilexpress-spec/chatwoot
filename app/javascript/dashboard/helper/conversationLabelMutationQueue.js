const conversationQueues = new Map();
const conversationVersions = new Map();
const inFlightIntents = new Map();

const normalizeIds = ids =>
  [...new Set((Array.isArray(ids) ? ids : [ids]).filter(id => id != null))]
    .map(String)
    .sort();

export const beginConversationLabelMutation = ids => {
  const versions = new Map();
  normalizeIds(ids).forEach(id => {
    const version = (conversationVersions.get(id) || 0) + 1;
    conversationVersions.set(id, version);
    versions.set(id, version);
  });
  return versions;
};

export const isLatestConversationLabelMutation = (id, versions) =>
  versions?.get(String(id)) === conversationVersions.get(String(id));

export const isConversationLabelMutationCurrent = (id, version) =>
  version === conversationVersions.get(String(id));

export const withConversationLabelMutationLock = (ids, operation) => {
  const keys = normalizeIds(ids);
  if (!keys.length) return Promise.resolve().then(operation);

  const predecessors = keys.map(
    id => conversationQueues.get(id) || Promise.resolve()
  );
  let release;
  const barrier = new Promise(resolve => {
    release = resolve;
  });
  const settledPredecessors = Promise.all(
    predecessors.map(promise => promise.catch(() => {}))
  );
  const tail = settledPredecessors.then(() => barrier);
  keys.forEach(id => conversationQueues.set(id, tail));

  return settledPredecessors.then(operation).finally(() => {
    release();
    keys.forEach(id => {
      if (conversationQueues.get(id) === tail) conversationQueues.delete(id);
    });
  });
};

export const withIdempotentConversationLabelMutation = (
  ids,
  intent,
  operation
) => {
  const key = `${normalizeIds(ids).join(':')}:${String(intent)}`;
  const inFlight = inFlightIntents.get(key);
  if (inFlight) return inFlight;

  let request;
  try {
    request = Promise.resolve(operation());
  } catch (error) {
    request = Promise.reject(error);
  }
  request = request
    .finally(() => {
      if (inFlightIntents.get(key) === request) inFlightIntents.delete(key);
    });
  inFlightIntents.set(key, request);
  return request;
};
