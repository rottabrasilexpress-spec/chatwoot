class Rotta::AutomaticLabels::CommercialIntent
  DECLINE = /\b(?:nao\s+(?:(?:quero|vou|pretendo|desejo)\s+(?:fech\w*|contrat\w*|agend\w*|reserv\w*|seguir)|tenho interesse)|sem interesse|desisti|fechei com outr\w*|nao vai dar)\b/
  NO_ACTION = /\b(?:prefiro|pode|quero|consegue|gostaria de)\s+(?:nao|sem)\s+(?:fech\w*|contrat\w*|agend\w*|reserv\w*|segu\w*)\b/
  NEUTRAL = /\A(?:(?:bom dia|boa tarde|boa noite|ola|oi|ok(?:ay)?|sim|certo|perfeito|obrigad[oa]|tudo certo|ta bom|beleza|blz|recebi|entendi|combinado|vou (?:ver|analisar|pensar|retornar|conversar))[\s,.!?]*)+\z/
  QUOTE_PERMISSION = /\A(?:(?:ok|sim|certo|perfeito|obrigad[oa]|tudo certo|ta bom|beleza)[,\s]+)*(?:(?:pode|consegue|poderia)\s+)?(?:enviar|mandar|envia|manda|me enviar|me mandar)\s+(?:(?:o|um)\s+)?(?:pre[\s-]*orcamento|orcamento|proposta)\s*(?:por favor|pfv)?[?!.\s]*\z/
  QUOTED_EXAMPLE = /\A(?:a frase|o texto|essa mensagem|exemplo|estou encaminhando)\b/
  CLOSING = /\b(?:(?:quero|vou|vamos|podemos|pode|posso|gostaria de|decidi)\s+(?:fechar|contratar|assinar|reservar|agendar)|(?:aceito|aprovo|confirmo)\s+(?:o|a|essa|esse)\s+(?:orcamento|proposta|opcao|contratacao|reserva)|(?:manda|mande|envia|envie|prepara|faca|fazer|emitir|emite)\s+(?:(?:o|um)\s+)?contrato|(?:quero|escolhi|prefiro|fico com|vou de|vou ficar com)\s+(?:a\s+)?opcao\s*\d|(?:eu\s+)?fecho)\b/
  CONTRACT = /\b(?:contrato|assinatura|contratacao|documentos?|cpf|rg|cnh|identidade|comprovante)\b/
  CONTRACT_ACTION = /\b(?:mand\w*|envi\w*|assin\w*|prepar\w*|emit\w*|anex\w*|segues?|precisa|pedir\w*|qua(?:is|l)|onde)\b/
  HUMAN = /\b(?:(?:falar|atendid[oa]|conversar|contato)\s+(?:com|por|do|da)\s+(?:(?:um|uma|o|a)\s+)?(?:pessoa|human[oa]|atendente|caio|responsavel|setor)|(?:chama|chame|passa|passe)\s+(?:(?:o|a|para|pro|pra)\s+)?(?:caio|human[oa]|atendente))\b/
  COMPLAINT = /\b(?:reclam\w*|urgente|urgencia|problema|falha|cobranca divergente)\b/
  NEGOTIATION = /\b(?:ficou car[oa]|achei car[oa]|muito car[oa]|valor (?:alto|pesado)|acima do (?:meu )?orcamento|fora do (?:meu )?orcamento|melhor[ae]r? (?:o|esse) (?:valor|preco)|(?:faz|fecha) por|consegue (?:baixar|melhorar|reduzir)|cabe no meu bolso)\b/
  PRICE_TOPIC = /
    (?:valor(?:es)?|precos?|orcamentos?|cotacao|diferenca\ de\ (?:valor|preco)|
       condic(?:ao|oes)\ de\ pagamento|quanto\ (?:fica|ficaria|sai|sairia|custa|custaria))
  /x
  PRICE_COMMAND = /
    (?<!nao\ )\b(?:veja|vejam|ve|verifica|verifique|confere|confira|calcula|calcule|simula|simule|
                 cota|cote|passe|informe|refaca|recalcule)\s+(?:[a-z]+\s+){0,5}#{PRICE_TOPIC}\b
  /x
  PRICE_REVISION = /
    (?:reajuste|revisao|recalculo|atualizacao|renegociacao)\s+
    (?:financeir[oa]|(?:d[oa]|n[oa])\s+(?:valor|preco|orcamento|frete))
  /x
  PRICE_REVISION_REQUEST = /
    \A#{PRICE_REVISION}[.!?\s]*\z|
    (?<!nao\ )\b(?:precis[oa](?:mos)?|quer[oa](?:mos)?|gostaria|solicito|tem\ como|da\ (?:pra|para))
    \s+(?:de\s+)?(?:um[a]?\s+)?#{PRICE_REVISION}\b
  /x
  NO_PRICE_REVISION = /
    \A(?:(?:ok|sim|certo|beleza|obrigad[oa])[,\s]+)*nao\s+(?:precis[oa](?:mos)?|quer[oa](?:mos)?|e\ necessario)\s+
    (?:(?:de\s+)?(?:um[a]?\s+)?#{PRICE_REVISION}|(?:rever|revisar|reajustar|atualizar|recalcular|alterar|mudar)
      \s+(?:(?:o|esse|este)\s+)?(?:valor|preco|orcamento|frete))(?:[,\s]+(?:obrigad[oa]|por\ favor))?[.!\s]*\z
  /x
  PRICE_VARIATION = /(?:com|sem)\s+(?:(?:os|as)\s+)?(?:ajudantes?|montagem|desmontagem|embalagem|parcelamento)/
  SHORT_PRICE_VARIATION = /\A(?:e\s+#{PRICE_VARIATION}[?!.\s]*|#{PRICE_VARIATION}\s*\?)\z/
  PRICED_CONTEXT = /\br\$\s*\d/
  COMMERCIAL = /\b(?:valor(?:es)?|precos?|descontos?|pagamento|pix|boleto|cartao|sinal|entrada|parcel\w*|a vista|taxas?|juros|ajudantes?|montagem|desmontagem|embalagem|servicos?|prazo|entrega|coleta|datas?|disponibil\w*|vagas?|reserva|agendamento|orcamentos?|proposta|contrato|contratacao)\b/
  QUESTION = /\?|\b(?:qual|quais|quanto|quando|como|onde|inclui|inclus[oa]s?|tem|da para|da pra|pode|posso|consigo|consegue|poderia|seria|queria|gostaria|preciso|quero|confirma\w*|me (?:explica|informa|passa|diga|manda|envia)|nao (?:vi|achei|encontrei|entendi|consta))\b/
  SHORT_COMMERCIAL = /\A(?:(?:e|o|a|no|na)\s+)*(?:valor(?:es)?|precos?|desconto|prazo|datas?|disponibilidade|em quantas (?:vezes|parcelas)|a vista|pix|pagamento|parcelamento|com (?:os )?ajudantes)[\s?!.]*\z/
  UNRESOLVED = /\b(?:nao (?:respondeu|esclareceu|resolveu|entendi)|(?:tenho|estou com|fiquei com|sigo com) duvida|ficou faltando (?:me dizer|confirmar|responder)|aguardando (?:a |o )?(?:confirmacao|resposta)|so preciso (?:confirmar|saber))\b/
  CONTEXTUAL_ACCEPTANCE = /\A(?:(?:ok|sim|certo|perfeito|beleza)[,\s]+)*(?:pode (?:seguir|prosseguir|dar andamento)|vamos nessa|fechado|eu aceito|aceito|confirmado)[!.,\s]*\z/
  CONTEXTUAL_QUESTION = /\b(?:caminhao|veiculo|dimens\w*|capacidade|porte|acesso|responsabilidade|seguro|cobertura|documentos?|contrat\w*|elevador|escadas?|endereco)\b/
  SPECIFIC_REQUEST = /\b(?:qual|quais|quanto|quando|como|onde|poderia|consegue|pode me|posso|preciso saber)\b/
  OFFER_TO_ADVANCE = /\b(?:(?:podemos|posso|quer|deseja|vamos)\s+(?:seguir|prosseguir|dar andamento|reservar|agendar|fechar|preparar o contrato)|qual\s+(?:dessas\s+)?opc\w+\s+(?:voce prefere|prefere|escolhe))\b/
  WAITING_ON_TEAM = /\b(?:(?:vou|vamos|irei)\s+(?:encaminhar|verificar|confirmar|consultar|ver)|(?:setor|equipe|responsavel)\s+(?:vai|ira|precisa|confirma\w*)|(?:aguarde|aguardar)\s+(?:o|a)\s+retorno)\b/

  def self.classify(content)
    text = normalize(content)
    return :none if text.empty? || text.match?(QUOTED_EXAMPLE)

    clauses = text.split(/\b(?:mas|porem|contudo|so que)\b/)
    last_decline = clauses.rindex { |clause| clause.match?(DECLINE) }
    active = (last_decline ? clauses.drop(last_decline + 1).join(' ') : text).strip
    return :none if active.empty? || active.match?(NEUTRAL) || active.match?(QUOTE_PERMISSION) || active.match?(NO_ACTION)

    return :clear if active.match?(CLOSING) || active.match?(HUMAN) || active.match?(NEGOTIATION) || active.match?(SHORT_COMMERCIAL)
    return :clear if active.match?(CONTRACT) && active.match?(CONTRACT_ACTION)
    return :none if active.match?(NO_PRICE_REVISION)
    return :clear if active.match?(PRICE_COMMAND) || active.match?(PRICE_REVISION_REQUEST)
    return :ambiguous if active.match?(SHORT_PRICE_VARIATION)
    return :clear if active.match?(COMMERCIAL) && active.match?(QUESTION)
    return :clear if active.match?(COMPLAINT) && (active.match?(COMMERCIAL) || active.match?(QUESTION))
    return :ambiguous if active.match?(UNRESOLVED) || active.match?(CONTEXTUAL_ACCEPTANCE)
    return :ambiguous if active.match?(QUESTION) && (active.match?(CONTEXTUAL_QUESTION) || active.match?(SPECIFIC_REQUEST))

    :none
  end

  def self.confirmed_by_context?(context)
    current = normalize(context[:last_message])
    messages = context[:recent_messages]
    last_company = normalize(messages.reverse.find { |message| message[:role] == 'empresa' }&.fetch(:content))
    return false if last_company.empty?

    return true if current.match?(CONTEXTUAL_ACCEPTANCE) && last_company.match?(OFFER_TO_ADVANCE)
    return true if current.match?(SHORT_PRICE_VARIATION) && last_company.match?(PRICED_CONTEXT)
    if current == 'o cliente enviou um anexo sem legenda.'
      return last_company.match?(CONTRACT) && last_company.match?(CONTRACT_ACTION) &&
             last_company.match?(/\b(?:contrato|contratacao)\b/)
    end

    last_customer = normalize(messages.reverse.find { |message| message[:role] == 'cliente' }&.fetch(:content))
    current.match?(UNRESOLVED) && last_company.match?(WAITING_ON_TEAM) &&
      last_customer.match?(COMMERCIAL) && last_customer.match?(QUESTION)
  end

  def self.normalize(content)
    I18n.transliterate(content.to_s).downcase.strip
  end
end
