const REACTION_LABEL_PATTERN = /\s*\[\s*(?:reação|reaction)\s*\]\s*$/iu;
const MEDIA_PLACEHOLDER_PATTERN =
  /^\[\s*(?:audio|image|video|document|file)\s*\]$/i;

/**
 * Removes provider presentation tokens while preserving real captions.
 * Uazapi can persist a reaction as "🥰 [reação]" and media captions as
 * "[image]"/"[audio]" alongside a real attachment.
 */
export const getMessageDisplayContent = (content, attachments = []) => {
  if (typeof content !== 'string') return '';

  const withoutReactionLabel = content.replace(REACTION_LABEL_PATTERN, '');
  const hasAttachment = Array.isArray(attachments) && attachments.length > 0;

  if (
    hasAttachment &&
    MEDIA_PLACEHOLDER_PATTERN.test(withoutReactionLabel.trim())
  ) {
    return '';
  }

  return withoutReactionLabel.trimEnd();
};
