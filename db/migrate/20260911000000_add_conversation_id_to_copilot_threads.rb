class AddConversationIdToCopilotThreads < ActiveRecord::Migration[7.0]
  def change
    add_column :copilot_threads, :conversation_id, :integer
    add_index :copilot_threads, [:account_id, :conversation_id], unique: true
  end
end
