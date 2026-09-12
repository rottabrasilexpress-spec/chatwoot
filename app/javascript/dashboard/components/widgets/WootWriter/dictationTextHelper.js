const normalizeWhitespace = value =>
  String(value || '')
    .replace(/\s+/g, ' ')
    .trim();

const capitalizeSentence = value => {
  if (!value) return '';
  return value.charAt(0).toLocaleUpperCase('pt-BR') + value.slice(1);
};

export const formatRealtimeTranscript = value => {
  const normalized = normalizeWhitespace(value);
  if (!normalized) return '';

  const capitalized = capitalizeSentence(normalized);
  return capitalized.replace(
    /^(olá|oi|bom dia|boa tarde|boa noite)\s+/i,
    '$1, '
  );
};

export const formatFinalTranscript = value => {
  const formatted = formatRealtimeTranscript(value);
  if (!formatted || /[.!?…]$/.test(formatted)) return formatted;
  return `${formatted}.`;
};
