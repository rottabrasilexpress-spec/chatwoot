class CreateConversationFollowings < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_followings do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :conversation_followings, [:account_id, :conversation_id], unique: true
  end
end
