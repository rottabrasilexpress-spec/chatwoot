import { buildCalculationResult, parseInventory } from './calculatorHelpers';

describe('calculatorHelpers', () => {
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
});
