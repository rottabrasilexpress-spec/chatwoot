class MessageStar < ApplicationRecord
  belongs_to :account
  belongs_to :message
  belongs_to :user

  validates :message_id, uniqueness: { scope: :user_id }
end
