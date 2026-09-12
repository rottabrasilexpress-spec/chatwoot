require 'digest'

module RottaCalculator
  class PreBudgetParser
    MAX_LINES = 300
    MAX_PACKAGES_PER_LINE = 30
    MAX_QUANTITY = 999
    ACTIVATION_WORDS = %w[sim incluso inclusa contratado contratada contratar ✅].freeze
    NEGATION_WORDS = ['a confirmar', 'talvez', 'por conta do cliente', 'já montado', 'ja montado', 'já desmontado', 'ja desmontado'].freeze

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
      parsed_services = extract_services(lines, inventory_source)

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

      cleaned = original.sub(/\A(?:[-*•·]|\d+[.)])\s*/, '').strip
      quantity = 1
      candidate = cleaned
      if (match = cleaned.match(/\A(\d{1,3})\s*(?:x|un(?:id(?:ades?)?)?|pe[cç]as?)\s+(.+)$/i))
        quantity = match[1].to_i
        candidate = match[2].strip
      elsif (match = cleaned.match(/\A(\d{1,3})\s+(.+)$/i)) && InventoryCatalog.find(match[2])
        quantity = match[1].to_i
        candidate = match[2].strip
      end
      return if candidate.match?(/\A(?:origem|destino|data|cliente|nome|carga|descarga)\b/i)
      return if quantity.zero? || quantity > MAX_QUANTITY

      catalog_entry = InventoryCatalog.find(candidate)
      return unless catalog_entry || candidate.match?(/[[:alpha:]]/)
      raise ArgumentError, "A linha #{original.inspect} excede #{MAX_PACKAGES_PER_LINE} volumes" if quantity > MAX_PACKAGES_PER_LINE

      {
        'original_line' => original,
        'name' => candidate,
        'quantity' => quantity,
        'catalog_name' => catalog_entry&.name,
        'manual_review' => catalog_entry.nil?
      }
    end

    def extract_services(lines, inventory_source)
      service_lines = (lines + inventory_source.to_s.lines).map { |line| InventoryCatalog.normalize(line) }
      text = service_lines.join(' ')
      normalized = InventoryCatalog.normalize(text)
      assembly_line = service_lines.find { |line| line.match?(/(?<!des)montag/) }.to_s
      disassembly_line = service_lines.find { |line| line.match?(/desmont/) }.to_s
      explicit_assembly = explicitly_requested?(assembly_line, /(?<!des)montag/)
      explicit_disassembly = explicitly_requested?(disassembly_line, /desmont/)
      {
        'helpers' => {
          'origin' => count_for(normalized, /(?:carga|origem).*?(\d+)\s*ajudantes?/),
          'destination' => count_for(normalized, /(?:descarga|destino).*?(\d+)\s*ajudantes?/) 
        },
        'assembly' => {
          'origin_disassembly' => explicit_disassembly ? count_for(disassembly_line, /desmont.*?(\d+)/, 1) : 0,
          'destination_assembly' => explicit_assembly ? count_for(assembly_line, /(?<!des)montag.*?(\d+)/, 1) : 0,
          'requested' => explicit_assembly || explicit_disassembly,
          'manual_review' => (normalized.match?(/montag|desmont/) && !(explicit_assembly || explicit_disassembly))
        },
        'materials' => {
          'selected' => normalized.match?(/material|embalagem|caixa|pl[aá]stico bolha/),
          'amount' => 0.0
        },
        'special_fee' => 0.0
      }
    end

    def explicitly_requested?(text, keyword)
      context = text.to_s
      return false if context.blank?
      return false if NEGATION_WORDS.any? { |word| context.include?(InventoryCatalog.normalize(word)) }

      context.match?(/\b(?:sim|inclus[oa]|contratad[oa]|contratar)\b|✅|(?:contrate|solicito|preciso|incluir|inclua|fazer)/)
    end

    def count_for(text, pattern, default = 0)
      match = text.match(pattern)
      match ? [[match[1].to_i, MAX_QUANTITY].min, 0].max : default
    end
  end
end
