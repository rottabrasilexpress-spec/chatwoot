import {
  reviewWorkspacePath,
  followingMessagePreview,
} from '../reviewWorkspace';
describe('workspace routing without trail labels', () => {
  it.each([
    'kelvin',
    'orcamento-feito',
    'primeiro-contato',
    'orcamento-tentativa-3',
  ])('opens %s in Todos', label => {
    expect(reviewWorkspacePath({ id: 5, labels: [label] }, 1)).toBe(
      '/app/accounts/1/conversations/5'
    );
  });
  it('archive overrides every other category', () => {
    expect(
      reviewWorkspacePath(
        { id: 5, labels: ['clientes-fechados', 'arquivado', 'finalizados'] },
        1
      )
    ).toBe('/app/accounts/1/archived/conversations/5');
  });
  it.each([
    'finalizados',
    'clientes-fechados',
    'emitir-contrato',
    'caio-atencao',
  ])('keeps %s category', label => {
    expect(reviewWorkspacePath({ id: 5, labels: [label, 'kelvin'] }, 1)).toBe(
      `/app/accounts/1/label/${label}/conversations/5`
    );
  });
  it('does not equate resolved without archive label to archived', () => {
    expect(
      reviewWorkspacePath({ id: 5, status: 'resolved', labels: [] }, 1)
    ).toBe('/app/accounts/1/conversations/5');
  });
  it('renders text and attachments without HTML execution', () => {
    expect(followingMessagePreview({ content: '<b>Olá</b>' })).toBe('Olá');
    expect(followingMessagePreview({ content_type: 'audio' })).toBe(
      'Mensagem de áudio'
    );
    expect(followingMessagePreview(null)).toContain('Nenhuma mensagem');
  });
});
