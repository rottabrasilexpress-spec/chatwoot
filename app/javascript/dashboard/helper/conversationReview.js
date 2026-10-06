import { frontendURL, conversationUrl } from './URLHelper';
import { matchesFilters } from '../store/modules/conversations/helpers/filterHelpers';
import {
  filterByConversationType,
  filterByUnattended,
} from '../store/modules/conversations/helpers';
import snakecaseKeys from 'snakecase-keys';

export const normalizeReviewFilters = filters => {
  if (!filters?.length) return [];
  return snakecaseKeys(filters, { deep: true }).map(filter => {
    let values = filter.values ?? [];
    if (filter.attribute_key === 'content' && typeof values === 'string')
      values = values.split(',');
    if (!Array.isArray(values)) values = [values];
    return {
      ...filter,
      values: values.map(value =>
        typeof value === 'object' ? value?.id : value
      ),
    };
  });
};

export const reviewViewKey = context => JSON.stringify(context);

export const createReviewPoint = (list, conversation, context, title) => {
  const index = list.findIndex(item => item.id === conversation.id);
  return {
    id: crypto.randomUUID(),
    view: reviewViewKey(context),
    title,
    context: { ...context, filters: normalizeReviewFilters(context.filters) },
    conversation_id: conversation.id,
    name: conversation.meta?.sender?.name || `#${conversation.id}`,
    remaining: list.slice(index + 1, index + 201).map(item => ({
      id: item.id,
      name: item.meta?.sender?.name || `#${item.id}`,
    })),
  };
};

export const reviewConversationEligible = (conversation, context, userId) => {
  const labels = (conversation.labels || []).map(label =>
    typeof label === 'string' ? label : label.title
  );
  const archived = conversation.rotta_archived || labels.includes('arquivado');
  if (context.conversationType === 'archived' ? !archived : archived)
    return false;
  if (context.label && !labels.includes(context.label)) return false;
  if (
    context.inboxId &&
    Number(conversation.inbox_id) !== Number(context.inboxId)
  )
    return false;
  if (
    context.teamId &&
    Number(conversation.meta?.team?.id) !== Number(context.teamId)
  )
    return false;
  if (context.status !== 'all' && conversation.status !== context.status)
    return false;
  const assignee = conversation.meta?.assignee?.id;
  if (context.assigneeType === 'me' && Number(assignee) !== Number(userId))
    return false;
  if (context.assigneeType === 'unassigned' && assignee) return false;
  if (context.conversationType === 'unread' && !conversation.unread_count)
    return false;
  if (
    !filterByUnattended(
      true,
      context.conversationType,
      conversation.first_reply_created_at,
      conversation.waiting_since
    )
  )
    return false;
  if (
    !filterByConversationType(
      true,
      context.conversationType,
      conversation.priority,
      conversation.last_non_activity_message,
      conversation.unread_count
    )
  )
    return false;
  return matchesFilters(conversation, context.filters || []);
};

export const reviewConversationPath = (point, accountId, id) =>
  frontendURL(
    conversationUrl({
      accountId,
      id,
      label: point.context.label,
      activeInbox: point.context.inboxId,
      teamId: point.context.teamId,
      foldersId: point.context.foldersId,
      conversationType: point.context.conversationType,
    })
  );
