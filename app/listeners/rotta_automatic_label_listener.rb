class RottaAutomaticLabelListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message&.account_id

    Rotta::AutomaticLabelsJob.perform_later(message.id)
  end
end
