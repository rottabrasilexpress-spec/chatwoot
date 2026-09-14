# == Schema Information
#
# Table name: global_ai_threads
#
#  id         :bigint           not null, primary key
#  account_id :bigint           not null
#  user_id    :bigint           not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class GlobalAiThread < ApplicationRecord
  belongs_to :account
  belongs_to :user
  has_many :global_ai_messages, dependent: :destroy_async

  validates :title, presence: true
end
