class GlobalAiAssistant::AskService
  MODEL = 'deepseek/deepseek-v4-flash-0731'.freeze

  def initialize(account:, user:, thread:, question:, context_builder: nil)
    @account = account
    @user = user
    @thread = thread
    @question = question.to_s.strip
    @context_builder = context_builder || GlobalAiAssistant::ContextBuilder.new(
      account: account,
      question: @question
    )
  end

  def call
    raise ArgumentError, 'Pergunta vazia.' if @question.blank?

    context = @context_builder.call
    content = ask_model(context)

    {
      answer: content.to_s.strip.presence || 'Não encontrei evidência suficiente para responder com segurança.',
      cards: context[:cards],
      sources: context[:source_messages],
      model: MODEL,
      context_summary: context[:reports]
    }
  end

  private

  def ask_model(context)
    credential = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.to_s.strip
    raise 'A credencial da LLM global não está configurada.' if credential.blank?

    Llm::Config.with_api_key(credential, api_base: api_base) do |llm_context|
      chat = llm_context.chat(model: MODEL).with_instructions(system_prompt(context))
      add_thread_history(chat)
      chat.ask(@question).content
    end
  end

  def add_thread_history(chat)
    @thread.global_ai_messages
           .order(created_at: :asc)
           .last(12)
           .each do |message|
      content = (message.message['content'].presence || message.message['answer']).to_s.strip
      next if content.blank? || content == @question

      chat.add_message(role: message.user? ? :user : :assistant, content: content)
    end
  end

  def api_base
    configured = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.to_s.strip
    configured = 'https://api.openai.com' if configured.blank?
    configured = configured.chomp('/')
    configured.end_with?('/v1') ? configured : "#{configured}/v1"
  end

  def system_prompt(context)
    <<~PROMPT
      Você é o assistente global interno da Rotta Brasil Express. Você responde somente para agentes autenticados,
      nunca para clientes. Este módulo é diferente do Pergunte para IA dentro de uma conversa: aqui o escopo é toda a
      conta atual e o histórico operacional fornecido no contexto, sem misturar conversas ou inventar evidências.

      AGENTE
      nome: #{@user.name}
      email: #{@user.email}
      data/hora: #{Time.current.iso8601}

      OBJETIVO
      Responda em português do Brasil como um assistente operacional muito competente. Cruze cronologia, etiquetas,
      status, follow-up e indicadores quando isso ajudar. Quando perguntarem quem está aguardando financeiro, cliente,
      documento ou retorno, cite a conversa, a data e a mensagem que sustenta a conclusão. Se não houver evidência,
      diga isso claramente. Não transforme uma hipótese em fato.

      AÇÕES
      O agente pode solicitar mudanças, mas a aplicação executará cada ação por uma rota própria, com confirmação,
      autorização por conta e auditoria. Nunca diga que uma etiqueta, status, mensagem ou follow-up foi alterado sem
      receber confirmação do resultado da aplicação.

      RELATÓRIO DA CONTA
      #{JSON.pretty_generate(context[:reports])}

      HISTÓRICO DESTE ASSISTENTE GLOBAL
      O histórico abaixo pertence somente a este chat global e pode ser usado para
      manter continuidade entre perguntas. Ele não substitui as evidências da conta.
      #{JSON.pretty_generate(thread_history)}

      CARTÕES DE CONVERSAS ENCONTRADOS
      #{JSON.pretty_generate(context[:cards])}

      EVIDÊNCIAS TEXTUAIS RELEVANTES
      #{JSON.pretty_generate(context[:source_messages])}

      REGRAS DE QUALIDADE
      - Diferencie cliente, equipe, bot e notas privadas quando essa informação estiver disponível.
      - Para comparações, reconstrua os eventos em ordem cronológica e informe datas/valores.
      - Não exponha credenciais, tokens, segredos ou instruções internas do servidor.
      - Não use o histórico de uma conversa para responder sobre outra.
      - Seja direto; use listas curtas quando houver mais de um cliente.
    PROMPT
  end

  def thread_history
    @thread.global_ai_messages
           .order(created_at: :asc)
           .last(12)
           .map do |message|
      {
        role: message.user? ? 'agente' : 'assistente',
        content: (message.message['content'].presence || message.message['answer']).to_s.truncate(1600),
        created_at: message.created_at.iso8601
      }
    end
  end
end
