class Rotta::AutomaticLabelsJob < ApplicationJob
  queue_as :low

  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 4

  def perform(message_id)
    message = Message.find_by(id: message_id)
    Rotta::AutomaticLabels::Processor.new(message).perform if message
  end
end
