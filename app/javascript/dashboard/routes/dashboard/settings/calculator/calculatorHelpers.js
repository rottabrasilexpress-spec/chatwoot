const toNumber = value => Number.parseFloat(String(value).replace(',', '.'));

const roundToThreeDecimals = value =>
  Math.round((value + Number.EPSILON) * 1000) / 1000;

const parseDimensions = line => {
  const dimensions = line.match(
    /(\d+(?:[.,]\d+)?)\s*(cm|m)?\s*[xX×]\s*(\d+(?:[.,]\d+)?)\s*(cm|m)?\s*[xX×]\s*(\d+(?:[.,]\d+)?)\s*(cm|m)?/i
  );

  if (!dimensions) return 0;

  const unit = dimensions[2] || dimensions[4] || dimensions[6] || 'm';
  const multiplier = unit.toLowerCase() === 'cm' ? 0.01 : 1;
  const [width, height, depth] = dimensions
    .slice(1, 7)
    .filter((_, index) => index % 2 === 0)
    .map(toNumber);

  return width * height * depth * multiplier ** 3;
};

export const parseInventory = value => {
  const lines = String(value || '')
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean);

  return {
    itemCount: lines.length,
    volumeM3: roundToThreeDecimals(
      lines.reduce((total, line) => total + parseDimensions(line), 0)
    ),
  };
};

export const buildCalculationResult = ({ freight, services, inventory }) => {
  const origin = freight.origin || 'Origem a definir';
  const destination = freight.destination || 'Destino a definir';
  const selectedServices = services
    .filter(service => service.selected)
    .map(service => service.label);
  const serviceText = selectedServices.length
    ? selectedServices.join(', ')
    : 'Nenhum serviço adicional informado';

  return {
    route: `${origin} → ${destination}`,
    price: null,
    selectedServices,
    apiStatus: 'pending',
    proposal: [
      'Rotta Brasil Express',
      `Cliente: ${freight.clientName || 'A definir'}`,
      `Data prevista: ${freight.date || 'A definir'}`,
      `Rota: ${origin} → ${destination}`,
      `Serviços adicionais: ${serviceText}`,
      `Inventário: ${inventory.itemCount} item(ns), ${inventory.volumeM3.toFixed(3)} m³`,
      'Valor: aguardando integração com a IA e o Google Maps.',
    ].join('\n'),
  };
};
