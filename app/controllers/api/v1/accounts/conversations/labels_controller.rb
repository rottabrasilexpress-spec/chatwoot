class Api::V1::Accounts::Conversations::LabelsController < Api::V1::Accounts::Conversations::BaseController
  include LabelConcern

  def index
    @labels = @conversation.labels_for_display
  end

  def create
    @conversation.with_lock do
      updated_labels = requested_labels
      save_pickup(updated_labels) if params.key?(:pickup)
      @conversation.update_labels(updated_labels)

      # Callbacks can load taggings before the new label list is persisted.
      # Return the saved association, not that pre-save in-memory snapshot.
      @conversation.taggings.reload
      @labels = @conversation.labels_for_display
      if @pickup && !@labels.include?(RottaPickup::CLOSED_LABEL)
        @conversation.errors.add(:base, 'A data só pode ser salva junto com Clientes Fechados.')
        raise ActiveRecord::RecordInvalid, @conversation
      end
    end
  ensure
    @conversation.rotta_pickup_confirmed = false if @conversation
  end

  private

  def requested_labels
    return permitted_params[:labels] unless params.key?(:add) || params.key?(:remove)

    (@conversation.label_list | Array(permitted_params[:add])) - Array(permitted_params[:remove])
  end

  def save_pickup(labels)
    unless Array(labels).include?(RottaPickup::CLOSED_LABEL)
      @conversation.errors.add(:base, 'A data só pode ser salva junto com Clientes Fechados.')
      raise ActiveRecord::RecordInvalid, @conversation
    end

    Current.account.labels.find_by!(title: RottaPickup::CLOSED_LABEL)
    @pickup = RottaPickup.save_for!(@conversation, permitted_params[:pickup] || {})
    @conversation.rotta_pickup_confirmed = true
  end

  def model
    @model ||= @conversation
  end

  def permitted_params
    params.permit(:conversation_id, labels: [], add: [], remove: [], pickup: [:starts_on, :ends_on, :delivery_on, :note])
  end
end
