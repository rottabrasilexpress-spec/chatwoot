class ConversationAi::ContextBuilder
  SESSION_PREFIX = 'chatwoot:conversation-ai'.freeze

  def initialize(conversation:, user:, question:)
    @conversation = conversation
    @user = user
    @question = question.to_s.strip
  end

  def payload
    {
      account_id: @conversation.account_id,
      conversation_id: @conversation.display_id.to_i,
      session_key: session_key,
      question: @question,
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
end
