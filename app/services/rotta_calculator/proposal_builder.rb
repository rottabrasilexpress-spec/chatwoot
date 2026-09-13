module RottaCalculator
  class ProposalBuilder
    def self.call(freight:, route:, inventory:, pricing:)
      selected = pricing.fetch('selected', {}).to_h.stringify_keys
      services = pricing.fetch('services', {}).to_h.stringify_keys
      services_lines = []
      services_lines << "Ajudantes na origem: #{services['helpers_origin']}" if services['helpers_origin'].to_i.positive?
      services_lines << "Ajudantes no destino: #{services['helpers_destination']}" if services['helpers_destination'].to_i.positive?
      services_lines << "Desmontagem na origem: #{services['disassembly_origin']}" if services['disassembly_origin'].to_i.positive?
      services_lines << "Montagem no destino: #{services['assembly_destination']}" if services['assembly_destination'].to_i.positive?
      services_lines << "Material e embalagem: R$ #{format('%.2f', services['materials'].to_f)}" if services['materials'].to_f.positive?
      services_lines << "Taxa especial: R$ #{format('%.2f', services['special_fee'].to_f)}" if services['special_fee'].to_f.positive?
      service_total = services['total'].to_f
      transport_only = selected['freight_only_price'].to_f + (services['total'].to_f * 0.5)
      header = [
        'ORÇAMENTO FINAL — ROTTA BRASIL EXPRESS',
        "Cliente: #{freight['client_name'].presence || 'A definir'}",
        "Data pretendida: #{freight['date'].presence || 'A definir'}",
        "Rota: #{freight['origin']} → #{freight['destination']}",
        "Distância: #{route['distance_km']} km | Tempo de caminhão: #{pricing['truck_duration_hours']} h",
        "Cubagem montada: #{inventory['mounted_m3']} m³ | desmontada: #{inventory['disassembled_m3']} m³"
      ]

      if service_total <= 0
        return (header + [
          '',
          "Valor do transporte: R$ #{format('%.2f', selected['freight_only_price'].to_f)}",
          '',
          'Responsabilidades: os itens devem estar embalados antes da coleta; móveis desmontáveis devem estar desmontados.',
          'Validade: 7 dias. A disponibilidade e a reserva só ficam garantidas após confirmação formal.',
          'O contrato formal será emitido posteriormente. Pagamento via Pix, débito ou crédito em até 12x, sujeito aos juros da operadora.'
        ]).join("\n")
      end

      service_text = services_lines.presence || ['Serviço adicional informado, com valor a confirmar.']

      (header + [
        '',
        'Opção 1 — Transporte + serviços',
        "Valor: R$ #{format('%.2f', selected['final_price'].to_f)}",
        '',
        'Opção 2 — Somente transporte (serviços por conta do cliente)',
        "Valor: R$ #{format('%.2f', transport_only)}",
        '',
        'Serviços considerados:',
        *service_text.map { |line| "- #{line}" },
        '',
        'Responsabilidades: os itens devem estar embalados antes da coleta; no transporte sem serviço, móveis desmontáveis devem estar desmontados.',
        'Validade: 7 dias. A disponibilidade e a reserva só ficam garantidas após confirmação formal.',
        'O contrato formal será emitido posteriormente. Pagamento via Pix, débito ou crédito em até 12x, sujeito aos juros da operadora.'
      ]).join("\n")
    end
  end
end
