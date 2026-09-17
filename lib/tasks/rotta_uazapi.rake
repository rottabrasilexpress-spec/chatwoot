namespace :rotta_uazapi do
  desc 'Lista claims UAZAPI pendentes há mais de STALE_AFTER_MINUTES minutos'
  task report_stale_pending_sends: :environment do
    stale_after_minutes = Integer(ENV.fetch('STALE_AFTER_MINUTES', '30'), 10)
    cutoff = stale_after_minutes.minutes.ago
    stale_messages = []

    Message.where(message_type: :outgoing)
           .where("content_attributes ->> 'rotta_uazapi_pending_echo' = ?", 'true')
           .find_each do |message|
      attributes = message.content_attributes.to_h.with_indifferent_access

      claimed_at = Time.zone.parse(attributes[:rotta_uazapi_claimed_at].to_s)
      claimed_at ||= message.updated_at
      next if claimed_at >= cutoff

      stale_messages << {
        message_id: message.id,
        conversation_id: message.conversation_id,
        track_id: attributes[:uazapi_track_id],
        claimed_at: claimed_at.iso8601
      }
    rescue ArgumentError
      next
    end

    if stale_messages.empty?
      puts 'Nenhum claim UAZAPI pendente e antigo foi encontrado.'
    else
      puts JSON.pretty_generate(stale_messages)
      puts "Total: #{stale_messages.size}"
      puts 'Verifique o track_id na UAZAPI antes de liberar qualquer claim.'
    end
  end

  desc 'Libera um claim UAZAPI específico após conferência manual no provedor'
  task release_pending_send: :environment do
    message_id = ENV['MESSAGE_ID'].presence
    abort 'Informe MESSAGE_ID=<id>.' if message_id.blank?
    abort 'Confirme com CONFIRM=I_UNDERSTAND.' unless ENV['CONFIRM'] == 'I_UNDERSTAND'

    message = Message.find(message_id)
    message.with_lock do
      attributes = message.content_attributes.to_h.with_indifferent_access
      pending = ActiveModel::Type::Boolean.new.cast(attributes[:rotta_uazapi_pending_echo])
      abort 'A mensagem não possui claim UAZAPI pendente.' unless pending

      attributes.delete(:rotta_uazapi_pending_echo)
      attributes.delete(:rotta_uazapi_claimed_at)
      message.update!(content_attributes: attributes)
    end

    puts "Claim UAZAPI liberado para a mensagem #{message.id}."
  end
end
