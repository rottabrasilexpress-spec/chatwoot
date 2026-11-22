class ScopeConversationAiHistoryToAgent < ActiveRecord::Migration[7.0]
  def up
    add_column :copilot_threads, :private_conversation_id, :bigint
    add_index :copilot_threads, [:account_id, :private_conversation_id, :user_id],
              unique: true, where: 'private_conversation_id IS NOT NULL', name: 'idx_copilot_private_conversation_history'

    execute <<~SQL.squish
      UPDATE copilot_threads AS threads SET private_conversation_id = conversation_id, conversation_id = NULL
      WHERE threads.conversation_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM copilot_messages AS entry
        WHERE entry.copilot_thread_id = threads.id AND entry.message_type = 0
      )
      AND NOT EXISTS (
        SELECT 1 FROM copilot_messages AS entry
        WHERE entry.copilot_thread_id = threads.id AND entry.message_type = 0
        AND (entry.message->>'author_id') IS DISTINCT FROM threads.user_id::text
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Private histories cannot be merged without exposing agent messages.'
  end
end
