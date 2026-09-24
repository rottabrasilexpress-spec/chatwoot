class Api::V1::Accounts::Conversations::LabelsController < Api::V1::Accounts::Conversations::BaseController
  include LabelConcern

  def index
    @labels = @conversation.labels_for_display
  end

  def create
    @conversation.with_lock do
      if params.key?(:add) || params.key?(:remove)
        current_labels = @conversation.label_list
        labels_to_add = Array(permitted_params[:add])
        labels_to_remove = Array(permitted_params[:remove])
        updated_labels = (current_labels + labels_to_add).uniq - labels_to_remove
        @conversation.update_labels(updated_labels)
      else
        @conversation.update_labels(permitted_params[:labels])
      end

      @labels = @conversation.labels_for_display
    end
  end

  private

  def model
    @model ||= @conversation
  end

  def permitted_params
    params.permit(:conversation_id, labels: [], add: [], remove: [])
  end
end
