class Rotta::AutomaticLabels::Settings
  KEYS = %w[first_contact kelvin caio_attention].freeze

  def self.for(account)
    raw = account.rotta_automatic_labels.is_a?(Hash) ? account.rotta_automatic_labels : {}
    KEYS.index_with { |key| ActiveModel::Type::Boolean.new.cast(raw[key]) }
  end

  def self.update(account, values)
    current = self.for(account)
    permitted = values.to_h.stringify_keys.slice(*KEYS)
    account.update!(rotta_automatic_labels: current.merge(permitted.transform_values { |value| ActiveModel::Type::Boolean.new.cast(value) }))
    self.for(account)
  end
end
