class CreateRottaAutomaticLabelLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :rotta_automatic_label_logs do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :message, foreign_key: { on_delete: :cascade }
      t.string :automation_key, null: false
      t.string :status, null: false
      t.string :event_key, null: false
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :rotta_automatic_label_logs, %i[account_id event_key], unique: true,
                                                                    name: 'idx_rotta_auto_label_logs_event'
    add_index :rotta_automatic_label_logs, %i[account_id automation_key created_at],
              name: 'idx_rotta_auto_label_logs_recent'
  end
end
