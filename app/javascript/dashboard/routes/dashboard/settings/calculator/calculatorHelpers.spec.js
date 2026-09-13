import {
  adjustQuantity,
  buildCalculationResult,
  buildInventoryAudit,
  formatDuration,
  parseInventory,
} from './calculatorHelpers';

describe('calculatorHelpers', () => {
  it('formats route duration using 24-hour days', () => {
    expect(formatDuration(2222)).toBe('1 dia e 13 horas');
    expect(formatDuration(60)).toBe('1 hora');
    expect(formatDuration(45)).toBe('45 minutos');
    expect(formatDuration(0)).toBe('Aguardando');
  });

  it('clamps visible service quantity controls to zero and the maximum', () => {
    expect(adjustQuantity(0, -1)).toBe(0);
    expect(adjustQuantity(2, 1)).toBe(3);
    expect(adjustQuantity(999, 1)).toBe(999);
    expect(adjustQuantity(2, -1)).toBe(1);
  });

  it('counts inventory lines and calculates cubic volume from metre dimensions', () => {
    expect(
      parseInventory('Sofá — 2.00 x 0.90 x 0.80 m\nMesa — 1.20 x 0.80 x 0.75 m')
    ).toEqual({
      itemCount: 2,
      volumeM3: 2.16,
    });
  });

  it('builds a Rotta calculation result without pretending to have API data', () => {
    expect(
      buildCalculationResult({
        freight: {
          clientName: 'Antônio',
          date: '2026-09-20',
          origin: 'São Paulo - SP',
          destination: 'Salvador - BA',
        },
        services: [
          { label: 'Montador', selected: true },
          { label: 'Armazenagem', selected: false },
        ],
        inventory: { itemCount: 2, volumeM3: 2.16 },
      })
    ).toEqual({
      route: 'São Paulo - SP → Salvador - BA',
      price: null,
      proposal: expect.stringContaining('Rotta Brasil Express'),
      selectedServices: ['Montador'],
      apiStatus: 'pending',
    });
  });

  it('audits mounted and disassembled volume with the Hub safety margins', () => {
    expect(
      buildInventoryAudit({
        mounted_m3: 10.22,
        disassembled_m3: 6.22,
        weight_kg: 561,
      })
    ).toEqual({
      mounted: {
        baseM3: 10.22,
        auditedM3: 11.446,
        marginPercent: 12,
        vehicle: 'HR / Bongo / Utilitário',
        capacityM3: 14,
        usagePercent: 82,
      },
      disassembled: {
        baseM3: 6.22,
        auditedM3: 7.464,
        marginPercent: 20,
        vehicle: 'Van / Kombi',
        capacityM3: 10,
        usagePercent: 75,
      },
      weightKg: 561,
      usesCubedWeight: false,
    });
  });
});
