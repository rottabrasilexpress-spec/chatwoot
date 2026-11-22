class CreateConversationAiBriefs < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_ai_briefs do |t|
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.datetime :triggered_at, precision: 6, null: false
      t.string :state, null: false
      t.string :labels, array: true, default: [], null: false
      t.bigint :customer_message_id
      t.jsonb :result, default: {}, null: false
      t.timestamps
      t.index [:conversation_id, :user_id], unique: true
    end
  end
end
