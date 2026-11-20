class Api::V1::Accounts::RottaPickupsController < Api::V1::Accounts::BaseController
  PAGE_SIZE = 30

  before_action :set_conversation, only: [:show, :complete]

  def index
    today = RottaPickup.today
    rows = schedules.sort_by do |pickup|
      expired = (pickup.ends_on || pickup.starts_on) < today
      [expired ? 1 : 0, expired ? -pickup.starts_on.jd : pickup.starts_on.jd, pickup.conversation.display_id]
    end
    page = params[:page].to_i.clamp(1, [rows.length.fdiv(PAGE_SIZE).ceil, 1].max)
    items = rows.slice((page - 1) * PAGE_SIZE, PAGE_SIZE) || []
    render json: { items: items.map { |pickup| card(pickup, today) }, page: page, total: rows.size, has_more: page * PAGE_SIZE < rows.size }
  end

  def show
    pickup = @conversation.rotta_pickup || RottaPickup.from_name(@conversation)
    render json: { name: @conversation.contact.name, pickup: pickup && date_fields(pickup) }
  end

  def reminders
    today = RottaPickup.today
    due = schedules.select { |pickup| pickup.reminder_due?(today) }
    unless due.empty?
      read = Redis::Alfred.with { |redis| redis.mget(*due.map { |pickup| reminder_key(pickup, today) }) }
      due = due.zip(read).filter_map { |pickup, confirmed| pickup unless confirmed }
    end
    items = due.sort_by(&:starts_on).first(250)
    render json: { day: today, items: items.map { |pickup| card(pickup, today) } }
  end

  def acknowledge
    today = RottaPickup.today
    if params[:day] == today.iso8601
      items = params.permit(items: [:id, :starts_on, :ends_on])[:items] || []
      shown = items.first(250).map { |item| [item[:id].to_s, item[:starts_on], item[:ends_on].presence] }.to_set
      due = schedules.select do |pickup|
        pickup.reminder_due?(today) &&
          shown.include?([pickup.conversation.display_id.to_s, pickup.starts_on.iso8601, pickup.ends_on&.iso8601])
      end
      Redis::Alfred.pipelined do |pipeline|
        due.each { |pickup| pipeline.set(reminder_key(pickup, today), '1', ex: 4.days.to_i) }
      end if due.any?
    end
    head :no_content
  end

  def complete
    @conversation.with_lock do
      labels = @conversation.label_list
      if !labels.include?(RottaPickup::CLOSED_LABEL) && labels.include?(RottaPickup::FINISHED_LABEL)
        return render json: { labels: labels }
      end

      pickup = @conversation.rotta_pickup || RottaPickup.from_name(@conversation)
      unless labels.include?(RottaPickup::CLOSED_LABEL) && same_dates?(pickup)
        return render json: { error: 'O agendamento mudou. Atualize a lista e confira a data antes de concluir.' }, status: :conflict
      end

      Current.account.labels.find_by!(title: RottaPickup::FINISHED_LABEL)
      @conversation.update_labels((labels - [RottaPickup::CLOSED_LABEL]) | [RottaPickup::FINISHED_LABEL])
      render json: { labels: @conversation.label_list }
    end
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:id])
    authorize @conversation, :show?
  end

  def schedules
    scope = Current.account.conversations.tagged_with(RottaPickup::CLOSED_LABEL)
    unless Current.account.account_users.find_by!(user: current_user).administrator?
      scope = scope.where(inbox_id: current_user.inboxes.select(:id)).or(scope.where(team_id: current_user.teams.select(:id)))
    end

    scope.includes(:contact, :rotta_pickup).filter_map do |conversation|
      next unless policy(conversation).show?

      pickup = conversation.rotta_pickup
      if pickup
        pickup if conversation.contact.name.to_s.end_with?(" #{pickup.date_label}")
      else
        RottaPickup.from_name(conversation)
      end
    end
  end

  def same_dates?(pickup)
    pickup && pickup.starts_on.iso8601 == params[:starts_on] && pickup.ends_on&.iso8601 == params[:ends_on].presence
  end

  def date_fields(pickup)
    { starts_on: pickup.starts_on, ends_on: pickup.ends_on, note: pickup.note }
  end

  def card(pickup, today)
    conversation = pickup.conversation
    name = conversation.contact.name
    suffix = name.to_s.match(RottaPickup::LEGACY_SUFFIX)&.[](:suffix)
    date_fields(pickup).merge(id: conversation.display_id, name: name, date_label: suffix, days_until: (pickup.starts_on - today).to_i)
  end

  def reminder_key(pickup, today)
    "rotta_pickups:read:#{Current.account.id}:#{current_user.id}:#{pickup.conversation.id}:#{today}:#{pickup.starts_on}:#{pickup.ends_on}"
  end
end
