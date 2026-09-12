module RottaCalculator
  class InventoryResolver
    MAX_UNIT_VOLUME_M3 = 1_000.0
    MAX_DIMENSION_MM = 100_000
    COMPATIBLE_VOLUME_DELTA_M3 = 0.05
    COMPATIBLE_RELATIVE_DELTA = 0.20

    def initialize(ai_estimates: [])
      @ai_estimates = Array(ai_estimates).map(&:to_h).map(&:stringify_keys)
    end

    def call(items)
      resolved = Array(items).map { |item| resolve_item(item) }
      {
        'items' => resolved,
        'item_count' => resolved.sum { |item| item['quantity'] },
        'mounted_m3' => resolved.sum { |item| item['mounted_m3'] * item['quantity'] }.round(3),
        'disassembled_m3' => resolved.sum { |item| item['disassembled_m3'] * item['quantity'] }.round(3),
        'weight_kg' => resolved.sum { |item| item['weight_kg'] * item['quantity'] }.round(1),
        'manual_review' => resolved.any? { |item| item['manual_review'] },
        'conflicts' => resolved.filter_map { |item| item['conflict'] }.uniq
      }
    end

    private

    def resolve_item(item)
      source = item.stringify_keys
      entry = InventoryCatalog.find(source['catalog_name'].presence || source['name'])
      estimate = find_ai_estimate(source['name'])
      catalog_values = entry && {
        'mounted_m3' => entry.mounted_m3,
        'disassembled_m3' => entry.disassembled_m3,
        'weight_kg' => entry.weight_kg
      }
      ai_values = valid_estimate(estimate)
      values, conflict = merge_values(catalog_values, ai_values)
      values ||= {
        'mounted_m3' => 0.0,
        'disassembled_m3' => 0.0,
        'weight_kg' => 0.0
      }

      {
        'original_line' => source['original_line'],
        'name' => source['name'],
        'catalog_name' => entry&.name,
        'quantity' => bounded_quantity(source['quantity']),
        'mounted_m3' => values['mounted_m3'],
        'disassembled_m3' => values['disassembled_m3'],
        'weight_kg' => values['weight_kg'],
        'disassemblable' => entry ? entry.disassemblable : !!estimate&.fetch('disassemblable', false),
        'estimated' => entry.nil?,
        'manual_review' => entry.nil? || conflict.present?,
        'conflict' => conflict
      }.compact
    end

    def find_ai_estimate(name)
      needle = InventoryCatalog.normalize(name)
      @ai_estimates.find { |estimate| InventoryCatalog.normalize(estimate['name']) == needle }
    end

    def valid_estimate(estimate)
      return unless estimate.is_a?(Hash)
      values = %w[mounted_m3 disassembled_m3 weight_kg].to_h do |key|
        [key, Float(estimate[key])]
      rescue ArgumentError, TypeError
        [key, nil]
      end
      return if values['mounted_m3'].nil? || values['mounted_m3'].negative? || values['mounted_m3'] > MAX_UNIT_VOLUME_M3
      return if values['disassembled_m3'].nil? || values['disassembled_m3'].negative? || values['disassembled_m3'] > MAX_UNIT_VOLUME_M3
      return if values['weight_kg'].nil? || values['weight_kg'].negative?

      values.transform_values { |value| value.round(3) }
    end

    def merge_values(catalog_values, ai_values)
      return [catalog_values, nil] if ai_values.blank?
      return [ai_values, nil] if catalog_values.blank?

      conflicts = %w[mounted_m3 disassembled_m3 weight_kg].filter_map do |key|
        catalog = catalog_values[key].to_f
        ai = ai_values[key].to_f
        delta = (catalog - ai).abs
        relative = delta / [catalog.abs, ai.abs, 0.001].max
        delta > COMPATIBLE_VOLUME_DELTA_M3 && relative > COMPATIBLE_RELATIVE_DELTA ? key : nil
      end
      merged = %w[mounted_m3 disassembled_m3 weight_kg].to_h do |key|
        [key, conflicts.include?(key) ? [catalog_values[key], ai_values[key]].max : ((catalog_values[key] + ai_values[key]) / 2.0).round(3)]
      end
      [merged, conflicts.present? ? "#{conflicts.join(', ')}: estimativas divergentes" : nil]
    end

    def bounded_quantity(value)
      [[value.to_i, 1].max, 999].min
    end
  end
end
