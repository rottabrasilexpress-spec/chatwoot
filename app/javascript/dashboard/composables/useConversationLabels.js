import { computed, ref } from 'vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import {
  isConversationLabelMutationCurrent,
  withIdempotentConversationLabelMutation,
} from 'dashboard/helper/conversationLabelMutationQueue';

const ARCHIVED_LABEL_KEYS = new Set(['arquivado', 'arquivados']);

const normalizedLabelKey = label =>
  String(label || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/^\[\d+\]\s*/, '')
    .replace(/^\d+[-\s]+/, '')
    .replace(/\s+/g, '-');

const isArchivedLabel = label =>
  ARCHIVED_LABEL_KEYS.has(normalizedLabelKey(label));

/**
 * Composable for managing conversation labels
 * @returns {Object} An object containing methods and computed properties for conversation labels
 */
export function useConversationLabels() {
  const store = useStore();
  const getters = useStoreGetters();
  const pendingLabelSelections = ref(new Map());

  const normalizeLabels = value => {
    if (Array.isArray(value)) return [...new Set(value)];
    if (Array.isArray(value?.labels)) return [...new Set(value.labels)];
    return [];
  };

  const conversationKey = id => String(id ?? '');

  const setPendingLabels = (id, labels) => {
    const next = new Map(pendingLabelSelections.value);
    const key = conversationKey(id);

    if (labels === null) {
      next.delete(key);
    } else {
      next.set(key, normalizeLabels(labels));
    }

    pendingLabelSelections.value = next;
  };

  const pendingLabelsFor = id =>
    pendingLabelSelections.value.get(conversationKey(id));

  const labelsMatch = (left, right) =>
    normalizeLabels(left).join('\u0000') ===
    normalizeLabels(right).join('\u0000');

  /**
   * The currently selected chat
   * @type {import('vue').ComputedRef<Object>}
   */
  const currentChat = computed(() => getters.getSelectedChat.value);

  /**
   * The ID of the current conversation
   * @type {import('vue').ComputedRef<number|null>}
   */
  const conversationId = computed(() => currentChat.value?.id);

  /**
   * All labels available for the account
   * @type {import('vue').ComputedRef<Array>}
   */
  const accountLabels = computed(() => getters['labels/getLabels'].value);

  /**
   * Labels currently saved to the conversation
   * @type {import('vue').ComputedRef<Array>}
   */
  const savedLabels = computed(() => {
    const pendingLabels = pendingLabelsFor(conversationId.value);
    if (pendingLabels) return pendingLabels;

    const hasStoredLabels = store.getters[
      'conversationLabels/hasConversationLabels'
    ](conversationId.value);

    if (hasStoredLabels) {
      return normalizeLabels(
        store.getters['conversationLabels/getConversationLabels'](
          conversationId.value
        )
      );
    }

    return normalizeLabels(currentChat.value?.labels);
  });

  /**
   * Labels currently active on the conversation
   * @type {import('vue').ComputedRef<Array>}
   */
  const activeLabels = computed(() =>
    accountLabels.value.filter(({ title }) => savedLabels.value.includes(title))
  );

  /**
   * Labels available but not active on the conversation
   * @type {import('vue').ComputedRef<Array>}
   */
  const inactiveLabels = computed(() =>
    accountLabels.value.filter(
      ({ title }) => !savedLabels.value.includes(title)
    )
  );

  /**
   * Updates the labels for the current conversation
   * @param {string[]} selectedLabels - Array of label titles to be set for the conversation
   * @returns {Promise<void>}
   */
  const onUpdateLabels = async selectedLabels => {
    const id = conversationId.value;
    const previousLabels = [...savedLabels.value];
    const labels = Array.isArray(selectedLabels) ? selectedLabels : [];
    const archivedLabel = labels.find(isArchivedLabel);
    const normalizedSelectedLabels = normalizeLabels(
      archivedLabel ? [archivedLabel] : labels
    );
    setPendingLabels(id, normalizedSelectedLabels);
    const intent = normalizedSelectedLabels
      .map(normalizedLabelKey)
      .sort()
      .join('|');
    try {
      const updated = await withIdempotentConversationLabelMutation(
        [id],
        `set:${intent}`,
        async () => {
          const result = await store.dispatch('conversationLabels/update', {
            conversationId: id,
            labels: normalizedSelectedLabels,
          });

          if (result?.status === 'superseded') return result;
          if (result?.status !== 'success' && result !== true) return false;

          await store.dispatch('labels/get', { forceNetwork: true });
          if (
            result?.version != null &&
            !isConversationLabelMutationCurrent(id, result.version)
          ) {
            return result;
          }

          const addedLabels = normalizedSelectedLabels.filter(
            label => !previousLabels.includes(label)
          );
          const removedLabels = previousLabels.filter(
            label => !normalizedSelectedLabels.includes(label)
          );

          addedLabels.forEach(label => {
            useAlert(`Etiqueta "${label}" adicionada à conversa.`, {
              ...(isArchivedLabel(label) ? { variant: 'danger' } : {}),
            });
          });
          removedLabels.forEach(label =>
            useAlert(`Etiqueta "${label}" removida da conversa.`)
          );

          return result;
        }
      );

      if (
        (updated === true || updated?.status === 'success') &&
        labelsMatch(pendingLabelsFor(id), normalizedSelectedLabels)
      ) {
        setPendingLabels(id, null);
      }
      if (
        (updated === false || updated?.status === 'failed') &&
        labelsMatch(pendingLabelsFor(id), normalizedSelectedLabels)
      ) {
        setPendingLabels(id, null);
      }
      return updated;
    } catch {
      if (labelsMatch(pendingLabelsFor(id), normalizedSelectedLabels)) {
        setPendingLabels(id, null);
      }
      return false;
    }
  };

  /**
   * Adds a label to the current conversation
   * @param {Object} value - The label object to be added
   * @param {string} value.title - The title of the label to be added
   */
  const addLabelToConversation = value => {
    const result = activeLabels.value.map(item => item.title);
    result.push(value.title);
    return onUpdateLabels(result);
  };

  /**
   * Removes a label from the current conversation
   * @param {string} value - The title of the label to be removed
   */
  const removeLabelFromConversation = value => {
    const result = activeLabels.value
      .map(label => label.title)
      .filter(label => label !== value);
    return onUpdateLabels(result);
  };

  return {
    accountLabels,
    savedLabels,
    activeLabels,
    inactiveLabels,
    addLabelToConversation,
    removeLabelFromConversation,
    onUpdateLabels,
  };
}
