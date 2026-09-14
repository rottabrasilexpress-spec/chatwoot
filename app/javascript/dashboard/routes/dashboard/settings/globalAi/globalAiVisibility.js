export const DEFAULT_GLOBAL_AI_OWNER_EMAIL = 'rottabrasilexpress@gmail.com';

export const canViewGlobalAi = ({ settings = {}, currentUser = {} }) => {
  const ownerId = settings.rotta_global_ai_owner_id;
  const sharedIds = Array.isArray(settings.rotta_global_ai_shared_user_ids)
    ? settings.rotta_global_ai_shared_user_ids.map(Number)
    : [];

  if (ownerId !== null && ownerId !== undefined && ownerId !== '') {
    return (
      Number(ownerId) === Number(currentUser.id) ||
      sharedIds.includes(Number(currentUser.id))
    );
  }

  return currentUser.email?.toLowerCase() === DEFAULT_GLOBAL_AI_OWNER_EMAIL;
};
