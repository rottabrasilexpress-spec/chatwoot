class ArchiveExistingRottaConversations < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      WITH archived_contacts AS (
        SELECT DISTINCT account_id, contact_id
        FROM conversations
        WHERE (',' || COALESCE(cached_label_list, '') || ',') LIKE '%,arquivado,%'
           OR (',' || COALESCE(cached_label_list, '') || ',') LIKE '%,arquivados,%'
      )
      UPDATE conversations
      SET status = 1,
          status_changed_at = COALESCE(status_changed_at, NOW()),
          waiting_since = NULL,
          updated_at = NOW()
      FROM archived_contacts
      WHERE conversations.account_id = archived_contacts.account_id
        AND conversations.contact_id = archived_contacts.contact_id
        AND conversations.status <> 1
    SQL
  end

  def down
    # Historical status cannot be inferred safely; archived conversations stay
    # archived when this migration is rolled back.
  end
end
