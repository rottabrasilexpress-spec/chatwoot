class CreateGlobalAiAssistant < ActiveRecord::Migration[7.0]
  def change
    create_table :global_ai_threads do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.timestamps
    end

    add_index :global_ai_threads, [:account_id, :user_id, :updated_at],
              name: 'index_global_ai_threads_on_account_user_updated'

    create_table :global_ai_messages do |t|
      t.references :global_ai_thread, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.integer :message_type, null: false, default: 0
      t.jsonb :message, null: false, default: {}
      t.timestamps
    end

    add_index :global_ai_messages, [:global_ai_thread_id, :created_at],
              name: 'index_global_ai_messages_on_thread_created'
  end
end
