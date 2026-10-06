import { frontendURL, conversationUrl } from './URLHelper';

// Workspace cards open the operational category, not an individual trail label.
export const reviewWorkspaceDestination = conversation => {
  const labels = (conversation.labels || []).map(label =>
    typeof label === 'string' ? label : label?.title
  );
  if (
    conversation.rotta_archived ||
    labels.some(label => ['arquivado', 'arquivados'].includes(label))
  )
    return { conversationType: 'archived' };
  const label = [
    'finalizados',
    'clientes-fechados',
    'emitir-contrato',
    'caio-atencao',
  ].find(value => labels.includes(value));
  return label ? { label } : {};
};

export const reviewWorkspacePath = (conversation, accountId) =>
  frontendURL(
    conversationUrl({
      accountId,
      id: conversation.id,
      ...reviewWorkspaceDestination(conversation),
    })
  );

export const followingMessagePreview = message => {
  if (!message) return 'Nenhuma mensagem pública nesta conversa.';
  const text = String(message.content || '')
    .replace(/<[^>]*>/g, '')
    .trim();
  if (text) return text;
  const types = {
    audio: 'Mensagem de áudio',
    image: 'Imagem',
    video: 'Vídeo',
    file: 'Arquivo',
    voice_call: 'Ligação',
  };
  return types[message.content_type] || 'Mensagem com anexo';
};
