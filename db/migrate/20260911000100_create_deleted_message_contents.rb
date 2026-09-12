class CreateDeletedMessageContents < ActiveRecord::Migration[7.2]
  def change
    create_table :deleted_message_contents do |t|
      t.references :message, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.text :content, null: false
      t.string :source, null: false
      t.datetime :deleted_at, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :deleted_message_contents, :expires_at
    add_index :deleted_message_contents, [:account_id, :expires_at]
    add_index :deleted_message_contents, :message_id, unique: true
  end
end
