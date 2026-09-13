const toNumber = value => Number.parseFloat(String(value).replace(',', '.'));

const roundToThreeDecimals = value =>
  Math.round((value + Number.EPSILON) * 1000) / 1000;

const roundToTwoDecimals = value =>
  Math.round((value + Number.EPSILON) * 100) / 100;

export const adjustQuantity = (value, delta, maximum = 999) => {
  const current = Math.trunc(Number(value) || 0);
  const change = Math.trunc(Number(delta) || 0);

  return Math.min(maximum, Math.max(0, current + change));
};

export const formatDuration = value => {
  const totalMinutes = Math.max(0, Math.round(Number(value) || 0));
  if (!totalMinutes) return 'Aguardando';

  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;
  const parts = [];

  if (days) parts.push(`${days} ${days === 1 ? 'dia' : 'dias'}`);
  if (hours) parts.push(`${hours} ${hours === 1 ? 'hora' : 'horas'}`);
  if (minutes && !days) {
    parts.push(`${minutes} ${minutes === 1 ? 'minuto' : 'minutos'}`);
  }

  return parts.join(' e ');
};

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

const VEHICLE_REFERENCES = [
  { label: 'Van / Kombi', capacityM3: 10 },
  { label: 'HR / Bongo / Utilitário', capacityM3: 14 },
  { label: 'VUC / Caminhão leve', capacityM3: 20 },
  { label: 'Caminhão 3/4', capacityM3: 30 },
];

const vehicleForVolume = volumeM3 =>
  VEHICLE_REFERENCES.find(vehicle => volumeM3 <= vehicle.capacityM3) ||
  VEHICLE_REFERENCES.at(-1);

const auditVolume = (baseM3, marginPercent) =>
  roundToThreeDecimals(Number(baseM3 || 0) * (1 + marginPercent / 100));

export const buildInventoryAudit = inventory => {
  const mountedBaseM3 = Number(inventory?.mounted_m3 || 0);
  const disassembledBaseM3 = Number(inventory?.disassembled_m3 || 0);
  const mountedM3 = auditVolume(mountedBaseM3, 12);
  const disassembledM3 = auditVolume(disassembledBaseM3, 20);
  const mountedVehicle = vehicleForVolume(mountedM3);
  const disassembledVehicle = vehicleForVolume(disassembledM3);

  const buildLoad = (baseM3, auditedM3, marginPercent, vehicle) => ({
    baseM3: roundToThreeDecimals(baseM3),
    auditedM3,
    marginPercent,
    vehicle: vehicle.label,
    capacityM3: vehicle.capacityM3,
    usagePercent: Math.round((auditedM3 / vehicle.capacityM3) * 100),
  });

  return {
    mounted: buildLoad(mountedBaseM3, mountedM3, 12, mountedVehicle),
    disassembled: buildLoad(
      disassembledBaseM3,
      disassembledM3,
      20,
      disassembledVehicle
    ),
    weightKg: roundToTwoDecimals(inventory?.weight_kg || 0),
    usesCubedWeight: false,
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
