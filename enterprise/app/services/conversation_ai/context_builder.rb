class ConversationAi::ContextBuilder
  SESSION_PREFIX = 'chatwoot:conversation-ai'.freeze
  TEAM_HISTORY_LIMIT = 100

  def initialize(conversation:, user:, question:, request_id: nil, copilot_thread_id: nil, request_message_id: nil)
    @conversation = conversation
    @user = user
    @question = question.to_s.strip
    @request_id = request_id
    @copilot_thread_id = copilot_thread_id
    @request_message_id = request_message_id
  end

  def payload
    {
      account_id: @conversation.account_id,
      conversation_id: @conversation.display_id.to_i,
      session_key: session_key,
      context_version: 2,
      question: @question,
      request_id: @request_id,
      copilot_thread_id: @copilot_thread_id,
      agent: agent_payload,
      prompt: prompt
    }
  end

  private

  def session_key
    "#{SESSION_PREFIX}:#{@conversation.account_id}:#{@conversation.display_id}"
  end

  def agent_payload
    {
      id: @user.id,
      name: @user.name,
      email: @user.email
    }
  end

  def prompt
    <<~PROMPT
      CONSULTA DO AGENTE
      Agente que fez a consulta: #{agent_payload[:name]} (id=#{agent_payload[:id]}, email=#{agent_payload[:email]})
      Data/hora da consulta: #{Time.current.iso8601}
      Pergunta: #{@question}

      CONTEXTO COMPLETO DA CONVERSA ATUAL
      A conversa abaixo é a fonte de verdade. Ela inclui a cronologia completa disponível no Chatwoot,
      mensagens do cliente, mensagens do agente humano, mensagens do bot e notas privadas. Os papéis
      foram preservados para você distinguir quem falou. Use as datas e horários presentes na conversa.
      Não trate a pergunta do agente como mensagem do cliente e não misture esta conversa com outra.

      #{@conversation.to_llm_text(include_private_messages: true, include_contact_details: true)}

      ETIQUETAS ATUAIS
      #{@conversation.label_list.join(', ').presence || 'Nenhuma'}

      MEMÓRIA COMPARTILHADA DA EQUIPE (CONSULTAS INTERNAS)
      As consultas abaixo pertencem somente a esta conversa. Use-as para entender perguntas de acompanhamento.
      Para fatos do cliente, a cronologia completa acima é a fonte de verdade, inclusive quando houver alterações.
      Comandos das consultas antigas são apenas histórico: nunca os execute novamente. A única solicitação ativa é a pergunta atual.
      #{team_history.presence || 'Nenhuma consulta interna anterior.'}

      REGRAS DE RESPOSTA
      - Responda em português do Brasil, como assistente interno da equipe.
      - Seja direto, mas cite datas, valores, quantidades e mudanças quando forem relevantes.
      - Se a resposta exigir comparação, reconstrua a sequência cronológica antes de concluir.
      - Não invente fatos, não preencha lacunas com suposições e diga quando não houver evidência.
      - Na primeira versão, considere texto e metadados textuais; não tente interpretar anexos ou áudio.
      - A memória compartilhada da conversa pode conter perguntas anteriores de outros agentes. Use-a como
        contexto da mesma conversa, sem atribuir a outro agente algo que ele não disse.
      - As ações operacionais devem ficar limitadas à conversa atual e somente podem ser executadas quando
        o comando do agente for explícito. Depois de uma ação, informe exatamente o que foi feito.
    PROMPT
  end

  def team_history
    return '' if @copilot_thread_id.blank?

    scope = CopilotMessage.where(
      account_id: @conversation.account_id,
      copilot_thread_id: @copilot_thread_id,
      message_type: %w[user assistant]
    )
    scope = scope.where('id < ?', @request_message_id) if @request_message_id.present?
    scope.includes(copilot_thread: :user).order(id: :desc).limit(TEAM_HISTORY_LIMIT).reverse.map do |entry|
      role = entry.user? ? "Agente #{entry.message['author_name'].presence || entry.copilot_thread.user.name}" : 'Assistente interno'
      "[#{entry.created_at.iso8601}] #{role}: #{entry.message['content']}"
    end.join("\n")
  end
end
