class Api::V1::Accounts::LabelsController < Api::V1::Accounts::BaseController
  before_action :fetch_label, except: [:index, :create]
  before_action :check_authorization

  def index
    @labels = policy_scope(Current.account.labels)
    # Count all visible labels in one account-scoped query, not two queries per
    # label on every sidebar refresh. Keep resolved conversations included.
    @label_counts = Current.account.conversations.joins(taggings: :tag)
                           .where(tags: { name: @labels.map(&:title) }).group('tags.name')
                           .pluck('tags.name', Arel.sql('COUNT(DISTINCT conversations.id)'),
                                  Arel.sql('COUNT(DISTINCT conversations.contact_id)'))
                           .to_h { |title, conversations, contacts| [title, [conversations, contacts]] }
  end

  def show; end

  def create
    @label = Current.account.labels.create!(permitted_params)
  end

  def update
    @label.update!(permitted_params)
  end

  def destroy
    label_title = @label.title
    account_id = Current.account.id
    label_deleted_at = Time.current

    @label.destroy!
    Labels::RemoveAssociationsJob.perform_later(
      label_title: label_title,
      account_id: account_id,
      label_deleted_at: label_deleted_at
    )
    head :ok
  end

  private

  def fetch_label
    @label = Current.account.labels.find(params[:id])
  end

  def permitted_params
    params.require(:label).permit(:title, :description, :color, :show_on_sidebar)
  end
end
