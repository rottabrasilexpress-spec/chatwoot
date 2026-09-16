namespace :rotta_uazapi do
  desc 'Lista claims UAZAPI pendentes há mais de STALE_AFTER_MINUTES minutos'
  task report_stale_pending_sends: :environment do
    stale_after_minutes = Integer(ENV.fetch('STALE_AFTER_MINUTES', '30'), 10)
    cutoff = stale_after_minutes.minutes.ago
    stale_messages = []

    Message.where(message_type: %i[outgoing template])
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
    stale_after_minutes = Integer(ENV.fetch('STALE_AFTER_MINUTES', '30'), 10)
    stale_cutoff = stale_after_minutes.minutes.ago

    message = Message.find(message_id)
    released = false

    ApplicationRecord.transaction do
      lock_key = "rotta-uazapi-send:#{message.account_id}:#{message.id}"
      sql = ApplicationRecord.sanitize_sql_array(
        ['SELECT pg_advisory_xact_lock(hashtext(?))', lock_key]
      )
      ApplicationRecord.connection.execute(sql)

      message.reload
      attributes = message.content_attributes.to_h.with_indifferent_access
      pending = ActiveModel::Type::Boolean.new.cast(attributes[:rotta_uazapi_pending_echo])
      abort 'A mensagem não possui claim UAZAPI pendente.' unless pending
      abort 'A mensagem já possui source_id; não libere este claim.' if message.source_id.present?

      claimed_at = Time.zone.parse(attributes[:rotta_uazapi_claimed_at].to_s)
      abort "O claim ainda não tem #{stale_after_minutes} minutos; não libere enquanto pode estar em voo." if claimed_at.blank? || claimed_at >= stale_cutoff
      expected_track_id = "message-#{message.id}"
      abort 'O track_id do claim é inconsistente; faça recuperação manual.' unless attributes[:uazapi_track_id].to_s == expected_track_id

      attributes.delete(:rotta_uazapi_pending_echo)
      attributes.delete(:rotta_uazapi_claimed_at)
      additional_attributes = message.additional_attributes.to_h.with_indifferent_access
      additional_attributes.delete(:rotta_uazapi_confirmation_pending)
      message.update!(content_attributes: attributes, additional_attributes: additional_attributes)
      released = true
    end

    puts "Claim UAZAPI liberado para a mensagem #{message.id}."
    puts 'Nenhum reenvio foi enfileirado automaticamente; inicie uma nova tentativa somente após a conferência operacional.' if released
  end
end
