class AddDeliveryOnToRottaPickups < ActiveRecord::Migration[7.1]
  def change
    add_column :rotta_pickups, :delivery_on, :date
    add_check_constraint :rotta_pickups, 'delivery_on IS NULL OR delivery_on >= starts_on', name: 'rotta_pickups_delivery_after_pickup'
  end
end
