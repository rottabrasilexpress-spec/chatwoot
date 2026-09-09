class CreateUazapiWebhookDeliveries < ActiveRecord::Migration[7.0]
  def change
    create_table :uazapi_webhook_deliveries do |t|
      t.bigint :account_id, null: false
      t.string :event, null: false
      t.string :provider_message_id
      t.string :track_id
      t.bigint :conversation_id
      t.string :status, null: false, default: 'received'
      t.integer :attempts, null: false, default: 1
      t.datetime :received_at, null: false
      t.datetime :processed_at
      t.integer :duration_ms
      t.integer :response_status
      t.string :error_class
      t.string :error_message
      t.string :payload_digest, null: false
      t.string :correlation_id, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :uazapi_webhook_deliveries, [:account_id, :received_at], name: 'idx_uazapi_deliveries_account_received'
    add_index :uazapi_webhook_deliveries, [:account_id, :status, :received_at], name: 'idx_uazapi_deliveries_account_status_received'
    add_index :uazapi_webhook_deliveries, [:account_id, :provider_message_id], name: 'idx_uazapi_deliveries_account_provider'
    add_index :uazapi_webhook_deliveries, :correlation_id, name: 'idx_uazapi_deliveries_correlation'
    add_index :uazapi_webhook_deliveries, :conversation_id, name: 'idx_uazapi_deliveries_conversation'
  end
end
