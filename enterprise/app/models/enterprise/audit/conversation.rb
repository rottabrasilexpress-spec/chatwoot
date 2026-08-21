module Enterprise::Audit::Conversation
  extend ActiveSupport::Concern

  included do
    audited only: [], on: [:destroy]
    after_update_commit :create_rotta_label_audit
  end

  private

  def create_rotta_label_audit
    return unless saved_change_to_label_list?

    previous_labels, current_labels = saved_change_to_label_list
    return unless previous_labels.is_a?(Array) && current_labels.is_a?(Array)

    Enterprise::AuditLog.create!(
      action: 'update',
      auditable: self,
      associated: account,
      user: Current.user,
      username: Current.user&.email,
      audited_changes: {
        'display_id' => display_id,
        'label_list' => [previous_labels, current_labels],
      }
    )
  end
end
