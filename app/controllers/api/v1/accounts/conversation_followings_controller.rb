class Api::V1::Accounts::ConversationFollowingsController < Api::V1::Accounts::BaseController
  before_action :set_conversation, only: [:show, :update, :destroy]

  def index
    scope = Current.account.conversations.joins('INNER JOIN conversation_followings ON conversation_followings.conversation_id = conversations.id')
    scope = scope.where(conversation_followings: { account_id: Current.account.id })
    unless Current.account.account_users.find_by!(user: current_user).administrator?
      scope = scope.where(inbox_id: current_user.inboxes.select(:id)).or(scope.where(team_id: current_user.teams.select(:id)))
    end
    scope = scope.where('conversation_followings.id < ?', params[:before_id].to_i) if params[:before_id].present?
    conversations = scope.includes({ taggings: :tag }, contact: { avatar_attachment: :blob })
                         .select('conversations.*, conversation_followings.id AS following_cursor')
                         .reorder('conversation_followings.id DESC').limit(31).to_a
    has_more = conversations.size > 30
    next_cursor = conversations.first(30).last&.following_cursor
    conversations = conversations.first(30).select { |conversation| policy(conversation).show? }
    messages = Current.account.messages.where(conversation_id: conversations.map(&:id), private: false, message_type: [:incoming, :outgoing])
                              .select('DISTINCT ON (conversation_id) messages.*').reorder(:conversation_id, created_at: :desc, id: :desc)
                              .includes(:attachments).index_by(&:conversation_id)
    render json: { items: conversations.map { |conversation| card(conversation, messages[conversation.id]) }, has_more: has_more, next_cursor: next_cursor }
  end

  def show
    render json: { following: ConversationFollowing.exists?(account: Current.account, conversation: @conversation) }
  end

  def update
    ConversationFollowing.find_or_create_by!(account: Current.account, conversation: @conversation)
    broadcast(true)
    render json: { following: true }
  end

  def destroy
    ConversationFollowing.where(account: Current.account, conversation: @conversation).delete_all
    broadcast(false)
    render json: { following: false }
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:id])
    authorize @conversation, :show?
  end

  def card(conversation, message)
    contact = conversation.contact
    { id: conversation.display_id, name: contact.name, avatar_url: contact.avatar_url, labels: conversation.label_list,
      rotta_archived: conversation.rotta_archived?, status: conversation.status,
      last_message: message && { id: message.id, content: message.content.to_s.first(1000), message_type: message.message_type,
                                 content_type: message.attachments.first&.file_type || message.content_type, created_at: message.created_at.to_i } }
  end

  def broadcast(following)
    tokens = Current.account.account_users.includes(:user).filter_map do |membership|
      user = membership.user
      context = { user: user, account: Current.account, account_user: membership }
      user.pubsub_token if ConversationPolicy.new(context, @conversation).show?
    end
    ActionCableBroadcastJob.perform_later(tokens, 'conversation.following_changed',
                                         { account_id: Current.account.id, id: @conversation.display_id, following: following })
  end
end
