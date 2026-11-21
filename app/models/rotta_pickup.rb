class RottaPickup < ApplicationRecord
  CLOSED_LABEL = 'clientes-fechados'.freeze
  SORT_KEYS = %w[pickup_asc pickup_desc].freeze
  FINISHED_LABEL = 'finalizados'.freeze
  NAME_SUFFIX_KEY = 'rotta_pickup_name_suffix'.freeze
  LEGACY_SUFFIX = /\s+(?<suffix>(?<start>\d{2}\/\d{2}\/\d{4})(?:\s+até\s+(?<end>\d{2}\/\d{2}(?:\/\d{4})?))?)\z/i
  SCHEDULE_CHANGED_EVENT = 'conversation.rotta_pickup_changed'.freeze
  TIME_ZONE = 'America/Sao_Paulo'.freeze

  belongs_to :conversation
  validates :starts_on, presence: true
  validate :ordered_dates

  def self.today
    Time.current.in_time_zone(TIME_ZONE).to_date
  end

  def self.parse_date(value)
    raw = value.to_s
    return unless raw.match?(/\A[1-9]\d{3}-\d{2}-\d{2}\z/)

    Date.iso8601(raw)
  rescue Date::Error
    nil
  end

  def self.from_name(conversation)
    dates = legacy_dates(conversation.contact.name)
    new(conversation: conversation, starts_on: dates.first, ends_on: dates.last) if dates
  end

  def self.legacy_dates(name)
    match = name.to_s.match(LEGACY_SUFFIX)
    return unless match

    start = Date.strptime(match[:start], '%d/%m/%Y')
    finish = legacy_end_date(match[:end], start)
    return if finish && finish < start

    [start, finish]
  rescue Date::Error
    nil
  end

  def self.legacy_end_date(value, start)
    return if value.blank?
    return Date.strptime(value, '%d/%m/%Y') if value.length == 10

    year = value.split('/').last.to_i < start.month ? start.year + 1 : start.year
    Date.strptime("#{value}/#{year}", '%d/%m/%Y')
  end

  def self.order_conversations(scope, descending:)
    scope = scope.left_joins(:rotta_pickup)
    direction = descending ? 'DESC' : 'ASC'
    legacy_rows = scope.unscope(:order, :limit, :offset).joins(:contact).where(rotta_pickups: { id: nil })
                       .where('contacts.name ~ ?', '[0-9]{2}/[0-9]{2}/[0-9]{4}')
                       .pluck('conversations.id', 'contacts.name')
    legacy_cases = legacy_rows.filter_map do |id, name|
      date = legacy_dates(name)&.first
      "WHEN #{Integer(id)} THEN #{connection.quote(date)}::date" if date
    end
    pickup_date = 'rotta_pickups.starts_on'
    if legacy_cases.any?
      pickup_date = "COALESCE(#{pickup_date}, CASE conversations.id #{legacy_cases.join(' ')} END)"
    end
    scope.reorder(Arel.sql("#{pickup_date} #{direction} NULLS LAST, rotta_pickups.delivery_on #{direction} NULLS LAST, conversations.display_id ASC"))
  end

  def date_label
    label = starts_on.strftime('%d/%m/%Y')
    return label unless ends_on && ends_on != starts_on

    finish_format = starts_on.year == ends_on.year ? '%d/%m' : '%d/%m/%Y'
    "#{label} até #{ends_on.strftime(finish_format)}"
  end

  def conversation_dates
    { starts_on: starts_on, ends_on: ends_on, delivery_on: delivery_on, updated_at: updated_at&.iso8601(6) }
  end

  def broadcast_schedule_change
    account = conversation.account
    tokens = account.account_users.includes(:user).filter_map do |membership|
      user = membership.user
      context = { user: user, account: account, account_user: membership }
      user.pubsub_token if ConversationPolicy.new(context, conversation).show?
    end
    ActionCableBroadcastJob.perform_later(tokens, SCHEDULE_CHANGED_EVENT,
                                         { account_id: account.id, id: conversation.display_id, rotta_pickup: conversation_dates })
  end

  def self.save_for!(conversation, submitted)
    start = parse_date(submitted[:starts_on])
    finish = parse_date(submitted[:ends_on])
    if start.nil? || (submitted[:ends_on].present? && finish.nil?) || (finish && finish < start)
      conversation.errors.add(:base, 'Informe uma data de coleta válida. A data final deve ser igual ou posterior à inicial.')
      raise ActiveRecord::RecordInvalid, conversation
    end

    pickup = find_or_initialize_by(conversation: conversation)
    delivery = submitted.key?(:delivery_on) ? parse_date(submitted[:delivery_on]) : pickup.delivery_on
    if (submitted[:delivery_on].present? && delivery.nil?) || (delivery && delivery < start)
      conversation.errors.add(:base, 'Informe uma data de entrega válida, igual ou posterior à coleta.')
      raise ActiveRecord::RecordInvalid, conversation
    end

    pickup.update!(starts_on: start, ends_on: finish, delivery_on: delivery, note: submitted[:note].to_s.strip.first(240).presence)
    pickup.sync_contact_name!
    pickup
  end

  def sync_contact_name!
    conversation.contact.sync_rotta_pickup_name!(date_label)
  end

  private

  def ordered_dates
    errors.add(:ends_on, :invalid) if starts_on && ends_on && ends_on < starts_on
    errors.add(:delivery_on, :invalid) if starts_on && delivery_on && delivery_on < starts_on
  end
end
