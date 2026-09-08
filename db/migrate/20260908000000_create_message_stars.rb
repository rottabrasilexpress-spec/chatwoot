class CreateMessageStars < ActiveRecord::Migration[7.1]
  def change
    create_table :message_stars do |t|
      t.references :account, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :message_stars, [:message_id, :user_id], unique: true
    add_index :message_stars, [:account_id, :user_id, :created_at]
  end
end
