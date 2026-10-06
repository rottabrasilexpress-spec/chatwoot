class Api::V1::Accounts::ReviewPointsController < Api::V1::Accounts::BaseController
  def show
    return show_candidate_membership if params[:candidate_id].present?

    saved = ConversationReviewState.find_by(account: Current.account, user: current_user)
    render json: saved&.data || { views: {}, history: [] }
  end

  def update
    points = params.require(:points).first(5).map { |point| sanitized_point(point) }
    saved = ConversationReviewState.find_or_create_by!(account: Current.account, user: current_user)
    saved.with_lock do
      state = saved.data
      points.each do |point|
        state['views'].delete_if { |key, item| key != point['view'] && item['context'] == point['context'] }
        state['views'][point['view']] = point
        state['history'] = ([point] + state['history'].reject { |item| item['id'] == point['id'] }).first(5)
      end
      state['views'] = state['views'].sort_by { |_key, value| value['updated_at'].to_s }.last(24).to_h
      saved.update!(data: state)
      render json: state
    end
  end

  private

  def show_candidate_membership
    conversation = Current.account.conversations.find_by!(display_id: params[:candidate_id])
    authorize conversation, :show?
    eligible = case params[:conversation_type]
               when 'mention'
                 Current.account.mentions.where(user: current_user, conversation_id: conversation.id).exists?
               when 'participating'
                 ConversationParticipant.where(account_id: Current.account.id, user_id: current_user.id, conversation_id: conversation.id).exists?
               else
                 false
               end
    render json: { eligible: eligible }
  end

  def sanitized_point(input)
    point = input.permit(:id, :view, :title, :name, :conversation_id,
                                         context: [:label, :conversationType, :inboxId, :teamId, :foldersId, :status, :assigneeType,
                                                   { filters: [:attribute_key, :filter_operator, :query_operator, { values: [] }] }],
                                         remaining: [:id, :name]).to_h
    raise ActionController::BadRequest, 'Invalid review point' if point['view'].to_s.length > 2000 || point['id'].blank? || !point['context'].is_a?(Hash)

    point['remaining'] = Array(point['remaining']).first(200).map do |candidate|
      { 'id' => candidate['id'].to_i, 'name' => candidate['name'].to_s.first(80) }
    end
    %w[id title name].each { |key| point[key] = point[key].to_s.first(160) }
    point['updated_at'] = Time.current.iso8601(3)
    point['context']['filters'] = Array(point['context']['filters']).first(20).map do |filter|
      filter.merge('values' => Array(filter['values']).first(30).map { |value| value.is_a?(String) ? value.first(100) : value })
    end
    point
  end
end
