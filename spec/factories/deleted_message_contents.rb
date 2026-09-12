# frozen_string_literal: true

FactoryBot.define do
  factory :deleted_message_content do
    association :message
    account { message.account }
    conversation { message.conversation }
    content { 'Conteúdo apagado pelo cliente' }
    source { 'customer' }
    deleted_at { 1.hour.ago }
    expires_at { 1.hour.from_now }
  end
end
