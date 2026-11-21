class Api::V1::Accounts::RottaPickupsController < Api::V1::Accounts::BaseController
  PAGE_SIZE = 30
  DATE_FIELDS = [:starts_on, :ends_on, :delivery_on, :note].freeze

  before_action :set_conversation, only: [:show, :update, :complete]

  def index
    today = RottaPickup.today
    direction = params[:sort_by] == 'pickup_desc' ? -1 : 1
    rows = schedules.sort_by do |pickup|
      delivery = pickup.delivery_on
      [direction * pickup.starts_on.jd, delivery ? 0 : 1, direction * (delivery&.jd || 0), pickup.conversation.display_id]
    end
    page = params[:page].to_i.clamp(1, [rows.length.fdiv(PAGE_SIZE).ceil, 1].max)
    items = rows.slice((page - 1) * PAGE_SIZE, PAGE_SIZE) || []
    render json: { items: items.map { |pickup| card(pickup, today) }, page: page, total: rows.size, has_more: page * PAGE_SIZE < rows.size }
  end

  def show
    render json: { name: @conversation.contact.name, pickup: current_pickup && date_fields(current_pickup) }
  end

  def update
    input = params.permit(:confirm_window, pickup: DATE_FIELDS, expected: DATE_FIELDS)
    pickup = @conversation.with_lock do
      original = current_pickup
      if !@conversation.label_list.include?(RottaPickup::CLOSED_LABEL) || !same_snapshot?(original, input[:expected])
        return render json: { error: 'O agendamento mudou. Abra o editor novamente para conferir as datas.' }, status: :conflict
      end

      submitted = input.fetch(:pickup, ActionController::Parameters.new).to_h.symbolize_keys
      if ActiveModel::Type::Boolean.new.cast(input[:confirm_window])
        chosen = RottaPickup.parse_date(submitted[:starts_on])
        unless original&.ends_on && original.ends_on > original.starts_on && chosen &&
               (original.starts_on..original.ends_on).cover?(chosen)
          return render json: { error: 'Selecione um dia dentro do intervalo de coleta.' }, status: :unprocessable_entity
        end

        submitted = date_fields(original).merge(submitted).merge(ends_on: nil)
      end

      RottaPickup.save_for!(@conversation, submitted)
    end

    pickup.broadcast_schedule_change
    render json: { pickup: date_fields(pickup), rotta_pickup: pickup.conversation_dates, contact: @conversation.contact.push_event_data }
  end

  def reminders
    today = RottaPickup.today
    due = reminder_candidates(today)
    due.reject! { |_, kind, _| kind == 'delivery' } unless params[:include_delivery] == 'true'
    unless due.empty?
      read = Redis::Alfred.with { |redis| redis.mget(*due.map { |pickup, kind, _| reminder_key(pickup, today, kind) }) }
      due = due.zip(read).filter_map { |reminder, confirmed| reminder unless confirmed }
    end
    items = due.sort_by { |_, kind, scheduled_on| [scheduled_on, kind == 'pickup' ? 0 : 1] }.first(250)
    render json: { day: today, items: items.map { |pickup, kind, scheduled_on| reminder_card(pickup, today, kind, scheduled_on) } }
  end

  def acknowledge
    today = RottaPickup.today
    if params[:day] == today.iso8601
      items = params.permit(items: [:id, :starts_on, :ends_on, :reminder_kind, :reminder_on])[:items] || []
      shown = items.first(250).map do |item|
        kind = item[:reminder_kind].presence || 'pickup'
        kind == 'delivery' ? [item[:id].to_s, kind, item[:reminder_on]] : [item[:id].to_s, kind, item[:starts_on], item[:ends_on].presence]
      end.to_set
      due = reminder_candidates(today).select do |pickup, kind, scheduled_on|
        id = pickup.conversation.display_id.to_s
        key = kind == 'delivery' ? [id, kind, scheduled_on.iso8601] : [id, kind, pickup.starts_on.iso8601, pickup.ends_on&.iso8601]
        shown.include?(key)
      end
      Redis::Alfred.pipelined do |pipeline|
        due.each { |pickup, kind, _| pipeline.set(reminder_key(pickup, today, kind), '1', ex: 4.days.to_i) }
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

      pickup = current_pickup
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

      conversation.rotta_pickup || RottaPickup.from_name(conversation)
    end
  end

  def same_dates?(pickup)
    pickup && pickup.starts_on.iso8601 == params[:starts_on] && pickup.ends_on&.iso8601 == params[:ends_on].presence &&
      (!params.key?(:delivery_on) || pickup.delivery_on&.iso8601 == params[:delivery_on].presence)
  end

  def current_pickup
    @conversation.rotta_pickup || RottaPickup.from_name(@conversation)
  end

  def same_snapshot?(pickup, expected)
    return expected.blank? unless pickup
    return false unless expected

    date_fields(pickup).all? { |field, value| value.to_s == expected[field].to_s }
  end

  def date_fields(pickup)
    { starts_on: pickup.starts_on, ends_on: pickup.ends_on, delivery_on: pickup.delivery_on, note: pickup.note }
  end

  def card(pickup, today)
    conversation = pickup.conversation
    contact = conversation.contact
    profile = contact.custom_attributes&.[]('rotta_move_profile') || contact.custom_attributes&.[]('rottaMoveProfile')
    route = profile.is_a?(Hash) ? profile.slice('origin', 'destination').transform_values { |value| value.is_a?(String) ? value.strip.presence : nil } : {}
    date_fields(pickup).merge(id: conversation.display_id, name: contact.name, phone: contact.phone_number, route: route,
                             date_label: pickup.date_label, days_until: (pickup.starts_on - today).to_i,
                             pickup_overdue: (pickup.ends_on || pickup.starts_on) < today)
  end

  def reminder_candidates(today)
    window = today..(today + 2)
    schedules.flat_map do |pickup|
      { 'pickup' => pickup.starts_on, 'delivery' => pickup.delivery_on }.filter_map do |kind, scheduled_on|
        [pickup, kind, scheduled_on] if scheduled_on && window.cover?(scheduled_on)
      end
    end
  end

  def reminder_card(pickup, today, kind, scheduled_on)
    card(pickup, today).merge(reminder_kind: kind, reminder_on: scheduled_on, days_until: (scheduled_on - today).to_i)
  end

  def reminder_key(pickup, today, kind)
    prefix = "rotta_pickups:read:#{Current.account.id}:#{current_user.id}:#{pickup.conversation.id}:#{today}"
    return "#{prefix}:delivery:#{pickup.delivery_on}" if kind == 'delivery'

    "#{prefix}:#{pickup.starts_on}:#{pickup.ends_on}"
  end
end
