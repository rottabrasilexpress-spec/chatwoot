class CreateConversationReviewStates < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_review_states do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.jsonb :data, null: false, default: { views: {}, history: [] }
      t.timestamps
    end
    add_index :conversation_review_states, [:account_id, :user_id], unique: true
  end
end
