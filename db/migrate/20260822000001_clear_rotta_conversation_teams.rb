class ClearRottaConversationTeams < ActiveRecord::Migration[7.1]
  def up
    account_id = ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', '1').to_i

    Conversation.where(account_id: account_id)
                .where.not(team_id: nil)
                .update_all(team_id: nil)
  end

  def down
    # Team ownership is intentionally not restored: Rotta uses one shared queue.
  end
end
