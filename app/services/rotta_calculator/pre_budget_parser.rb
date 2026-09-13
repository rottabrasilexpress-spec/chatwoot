require 'digest'

module RottaCalculator
  class PreBudgetParser
    MAX_LINES = 300
    MAX_PACKAGES_PER_LINE = 30
    MAX_QUANTITY = 999
    ACTIVATION_WORDS = %w[sim incluso inclusa contratado contratada contratar ✅].freeze
    NEGATION_WORDS = ['a confirmar', 'talvez', 'por conta do cliente', 'já montado', 'ja montado', 'já desmontado', 'ja desmontado'].freeze
    DIMENSIONS_PATTERN = /(?<first>\d+(?:[,.]\d+)?)\s*(?<unit_first>mm|cm|m)?\s*[x×]\s*(?<second>\d+(?:[,.]\d+)?)\s*(?<unit_second>mm|cm|m)?\s*[x×]\s*(?<third>\d+(?:[,.]\d+)?)\s*(?<unit_third>mm|cm|m)?/i

    def initialize(reading_text:, freight: {}, inventory: {}, services: {})
      @reading_text = reading_text.to_s
      @freight = freight.to_h.stringify_keys
      @inventory = inventory.to_h.stringify_keys
      @services = services.is_a?(Hash) ? services.stringify_keys : {}
    end

    def call
      lines = @reading_text.lines.map { |line| line.strip }.reject(&:empty?)
      raise ArgumentError, "O texto de leitura não pode ter mais de #{MAX_LINES} linhas" if lines.length > MAX_LINES

      inventory_source = @inventory['text'].presence || inventory_section(lines).join("\n")
      parsed_inventory = parse_inventory(inventory_source)
      freight = extract_freight(lines)
      parsed_services = extract_services(lines, parsed_inventory['items'])

      {
        'client_name' => freight['client_name'],
        'date' => freight['date'],
        'origin' => freight['origin'],
        'destination' => freight['destination'],
        'inventory' => parsed_inventory,
        'services' => parsed_services,
        'snapshot_hash' => Digest::SHA256.hexdigest(@reading_text),
        'snapshot_algorithm' => 'sha256',
        'source_line_count' => lines.length
      }
    end

    private

    def extract_freight(lines)
      {
        'client_name' => explicit_or_payload(lines, /(?:cliente|nome)\s*[:=-]\s*(.+)$/i, @freight['client_name']),
        'date' => explicit_or_payload(lines, /(?:data(?: pretendida)?|coleta)\s*[:=-]\s*(.+)$/i, @freight['date']),
        'origin' => explicit_or_payload(lines, /origem\s*[:=-]\s*(.+)$/i, @freight['origin']),
        'destination' => explicit_or_payload(lines, /destino\s*[:=-]\s*(.+)$/i, @freight['destination'])
      }
    end

    def explicit_or_payload(lines, pattern, fallback)
      match = lines.filter_map { |line| line.match(pattern)&.captures&.first }.first
      (match.presence || fallback).to_s.strip.presence
    end

    def inventory_section(lines)
      started = false
      lines.filter_map do |line|
        normalized = InventoryCatalog.normalize(line)
        if normalized.match?(/\binventario\b|\bitens?\b|\bmobiliario\b/)
          started = true
          next
        end
        if started && normalized.match?(/\b(servicos?|ajudantes?|montagem|desmontagem|observacoes?|origem|destino)\b/)
          started = false
          next
        end
        started ? line : nil
      end
    end

    def parse_inventory(source)
      items = source.to_s.lines.filter_map { |line| parse_inventory_line(line) }
      {
        'items' => items,
        'item_count' => items.sum { |item| item['quantity'] },
        'line_count' => items.length,
        'raw_text' => source.to_s
      }
    end

    def parse_inventory_line(line)
      original = line.to_s.strip
      return if original.blank?
      return if original.match?(/\A(?:invent[aá]rio|itens?|mobili[aá]rio|lista|observa[cç][oõ]es?)\b/i)

      cleaned = original.sub(/\A(?:[-*•·]\s*)?/, '').sub(/\A\d+[.)]\s*/, '').strip
      quantity = 1
      candidate = cleaned
      if (match = cleaned.match(/\A\[(\d{1,3})\]\s*(.+)$/i))
        quantity = match[1].to_i
        candidate = match[2].strip
      elsif (match = cleaned.match(/\A(\d{1,3})\s*(?:x|un(?:id(?:ades?)?)?|pe[cç]as?)\s+(.+)$/i))
        quantity = match[1].to_i
        candidate = match[2].strip
      elsif (match = cleaned.match(/\A(\d{1,3})\s+(.+)$/i)) && InventoryCatalog.find(match[2])
        quantity = match[1].to_i
        candidate = match[2].strip
      end
      return if candidate.match?(/\A(?:origem|destino|data|cliente|nome|carga|descarga)\b/i)
      return if quantity.zero? || quantity > MAX_QUANTITY

      return unless candidate.match?(/[[:alpha:]]/)
      raise ArgumentError, "A linha #{original.inspect} excede #{MAX_PACKAGES_PER_LINE} volumes" if quantity > MAX_PACKAGES_PER_LINE

      dimensions = extract_dimensions(candidate)
      candidate = dimensions[:name]
      catalog_entry = InventoryCatalog.find(candidate)

      {
        'original_line' => original,
        'name' => candidate,
        'quantity' => quantity,
        'catalog_name' => catalog_entry&.name,
        'manual_review' => catalog_entry.nil?
      }.merge(dimensions.except(:name).stringify_keys)
    end

    def extract_dimensions(candidate)
      match = candidate.match(DIMENSIONS_PATTERN)
      return { name: candidate.strip } unless match

      shared_unit = match[:unit_first].presence || match[:unit_second].presence || match[:unit_third].presence
      dimensions = %i[first second third].each_with_index.map do |key, index|
        value = Float(match[key].tr(',', '.'))
        unit_key = %i[unit_first unit_second unit_third][index]
        unit = match[unit_key].presence || shared_unit
        millimetres = value * { 'mm' => 1.0, 'cm' => 10.0, 'm' => 1000.0 }.fetch(unit.to_s.downcase, 1.0)
        raise ArgumentError, 'As dimensões devem ser maiores que zero' unless millimetres.positive?
        raise ArgumentError, 'Cada dimensão deve ter no máximo 100000 mm' if millimetres > 100_000

        millimetres
      end
      measured_m3 = dimensions.reduce(:*) / 1_000_000_000.0
      raise ArgumentError, 'O volume informado não pode exceder 1000 m³' if measured_m3 > 1_000

      {
        name: candidate.sub(match[0], '').sub(/\s*(?:[—–-]|[,:;])\s*\z/, '').gsub(/[\[\](){};,]+\z/, '').strip,
        dimensions_mm: dimensions,
        measured_m3: measured_m3.round(6)
      }
    end

    def extract_services(lines, inventory_items)
      raw_service_lines = lines.select { |line| service_line?(line) }
      normalized_lines = raw_service_lines.map { |line| InventoryCatalog.normalize(line) }
      normalized = normalized_lines.join(' ')
      assembly_line = raw_service_lines.find { |line| InventoryCatalog.normalize(line).match?(/(?<!des)montag/) }.to_s
      disassembly_line = raw_service_lines.find { |line| InventoryCatalog.normalize(line).match?(/desmont/) }.to_s
      explicit_assembly = explicitly_requested?(assembly_line)
      explicit_disassembly = explicitly_requested?(disassembly_line)
      assembly_count = explicit_assembly ? service_item_count(assembly_line, inventory_items) : 0
      disassembly_count = explicit_disassembly ? service_item_count(disassembly_line, inventory_items) : 0
      materials_line = raw_service_lines.find { |line| InventoryCatalog.normalize(line).match?(/material|embalagem|plastico bolha/) }.to_s
      {
        'helpers' => {
          'origin' => count_for(normalized, /(?:carga|origem).*?(\d+)\s*ajudantes?/),
          'destination' => count_for(normalized, /(?:descarga|destino).*?(\d+)\s*ajudantes?/) 
        },
        'assembly' => {
          'origin_disassembly' => disassembly_count,
          'destination_assembly' => assembly_count,
          'requested' => explicit_assembly || explicit_disassembly,
          'manual_review' => (normalized.match?(/montag|desmont/) && !(explicit_assembly || explicit_disassembly)) ||
            ((explicit_assembly || explicit_disassembly) && inventory_items.any? { |item| item['manual_review'] } &&
              [assembly_line, disassembly_line].any? { |line| InventoryCatalog.normalize(line).match?(/todos os moveis/) })
        },
        'materials' => {
          'selected' => explicitly_requested?(materials_line),
          'amount' => 0.0
        },
        'special_fee' => 0.0
      }
    end

    def service_line?(line)
      InventoryCatalog.normalize(line).match?(/ajudantes?|carga|descarga|desmontagem|montagem|material|embalagem|taxa especial|seguro|armazenagem/)
    end

    def service_item_count(line, inventory_items)
      normalized = InventoryCatalog.normalize(line)
      unless normalized.match?(/todos os moveis/)
        target = normalized.split(':', 2).last.to_s
          .gsub(/\b(?:sim|inclus[oa]|contratad[oa]|contratar|contrate|solicito|preciso|incluir|inclua|fazer)\b/, ' ')
          .gsub(/\d+/, ' ').strip
        if target.present?
          matches = inventory_items.select do |item|
            item_name = InventoryCatalog.normalize(item['name'])
            item_name.include?(target) || target.include?(item_name)
          end
          return matches.sum { |item| item['quantity'].to_i }.clamp(0, MAX_QUANTITY) if matches.present?
        end

        return count_for(normalized, /(?:desmont|montag).*?(\d+)/, 1)
      end

      inventory_items.select do |item|
        entry = InventoryCatalog.find(item['catalog_name'].presence || item['name'])
        entry&.disassemblable
      end.sum { |item| item['quantity'].to_i }.clamp(0, MAX_QUANTITY)
    end

    def explicitly_requested?(text)
      context = text.to_s
      return false if context.blank?
      normalized = InventoryCatalog.normalize(context)
      return false if normalized.match?(/\bnao\b/) || NEGATION_WORDS.any? { |word| normalized.include?(InventoryCatalog.normalize(word)) }
      return true if context.include?('✅')

      normalized.match?(/\b(?:sim|inclus[oa]|contratad[oa]|contratar|contrate|solicito|preciso|incluir|inclua|fazer)\b/)
    end

    def count_for(text, pattern, default = 0)
      match = text.match(pattern)
      match ? [[match[1].to_i, MAX_QUANTITY].min, 0].max : default
    end
  end
end
