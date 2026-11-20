class CreateRottaPickups < ActiveRecord::Migration[7.1]
  def change
    create_table :rotta_pickups do |t|
      t.references :conversation, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.date :starts_on, null: false
      t.date :ends_on
      t.string :note, limit: 240
      t.timestamps
    end
    add_check_constraint :rotta_pickups, 'ends_on IS NULL OR ends_on >= starts_on', name: 'rotta_pickups_valid_window'
  end
end
