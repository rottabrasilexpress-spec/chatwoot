class CreateGlobalAiActionReceipts < ActiveRecord::Migration[7.0]
  def change
    create_table :global_ai_action_receipts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :idempotency_key, null: false
      t.string :action_name, null: false
      t.bigint :conversation_display_id, null: false
      t.jsonb :response, null: false, default: {}
      t.datetime :completed_at
      t.timestamps
    end

    add_index :global_ai_action_receipts,
              [:account_id, :user_id, :idempotency_key],
              unique: true,
              name: 'index_global_ai_action_receipts_on_idempotency_key'
  end
end
