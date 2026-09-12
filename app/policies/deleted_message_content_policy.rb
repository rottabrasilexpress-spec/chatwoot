class DeletedMessageContentPolicy < ApplicationPolicy
  def show?
    return false unless user.is_a?(User)
    return false unless account_user&.agent? || account_user&.administrator?
    return false unless record.account_id == account&.id

    ConversationPolicy.new(user_context, record.conversation).show?
  end
end
