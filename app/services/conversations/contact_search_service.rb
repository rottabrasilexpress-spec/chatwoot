class Conversations::ContactSearchService
  NAME_SQL = "translate(lower(COALESCE(contacts.name, '')), 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc')".freeze

  def initialize(scope, query)
    @scope = scope
    @query = query.to_s.strip.first(120)
  end

  def perform
    return @scope.none if @query.blank?

    # One contact and contact_inbox per conversation: no message join, DISTINCT,
    # or pagination here. The finder keeps permissions and paginates afterwards.
    conditions, binds = search_conditions
    order = ActiveRecord::Base.sanitize_sql_array([
      "CASE WHEN #{NAME_SQL} LIKE :prefix THEN 0 WHEN #{NAME_SQL} LIKE :text THEN 1 ELSE 2 END",
      binds
    ])
    @scope.left_joins(:contact, :contact_inbox).where(conditions, binds).order(Arel.sql(order))
  end

  private

  def search_conditions
    normalized = ActiveSupport::Inflector.transliterate(@query).downcase
    escaped = ActiveRecord::Base.sanitize_sql_like(normalized)
    binds = { text: "%#{escaped}%", prefix: "#{escaped}%", normalized: normalized }
    conditions = ["#{NAME_SQL} LIKE :text", 'lower(COALESCE(contacts.email, \'\')) LIKE :text']
    digits = @query.gsub(/\D/, '')

    if @query.match?(/\A[+\d\s().-]+\z/) && digits.present?
      binds[:phone] = "%#{digits}%"
      %w[contacts.phone_number contacts.identifier contact_inboxes.source_id].each do |field|
        conditions << "regexp_replace(COALESCE(#{field}, ''), '[^0-9]', '', 'g') LIKE :phone"
      end
    elsif normalized.length >= 3
      # pg_trgm already exists in Chatwoot. Conservative suggestions only for
      # name queries, never fuzzy phone numbers or cross-account records.
      conditions << "word_similarity(:normalized, #{NAME_SQL}) >= 0.55"
    end

    ["(#{conditions.join(' OR ')})", binds]
  end
end
