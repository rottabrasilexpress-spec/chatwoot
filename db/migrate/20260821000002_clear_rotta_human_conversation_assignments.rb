class ClearRottaHumanConversationAssignments < ActiveRecord::Migration[7.1]
  def up
    account_id = ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i

    Conversation.where(account_id: account_id)
                .where.not(assignee_id: nil)
                .update_all(assignee_id: nil)
  end

  def down
    # Human assignees cannot be restored safely because the migration does not
    # retain ownership history. The audit trail remains available in activities.
  end
end
