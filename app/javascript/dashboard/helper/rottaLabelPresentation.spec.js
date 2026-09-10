import {
  getLabelFilterOptions,
  getLabelPresentationColor,
  getLabelPresentationTitle,
} from './rottaLabelPresentation';

describe('Rotta label presentation', () => {
  const labels = [
    { title: 'segundo-contato', color: '#f59e0b' },
    { title: 'kelvin', color: '#c026d3' },
    { title: 'custom-label', color: '#64748b' },
  ];

  it('keeps the technical value while presenting the same label name and color as the chat', () => {
    expect(getLabelPresentationTitle(labels[0])).toBe('Segundo contato');
    expect(getLabelPresentationColor(labels[0])).toBe('#f59e0b');

    expect(getLabelFilterOptions(labels)).toEqual([
      {
        value: '',
        label: 'Filtrar por etiqueta',
        icon: 'i-lucide-tags',
      },
      {
        value: 'segundo-contato',
        label: 'Segundo contato',
        color: '#f59e0b',
      },
      {
        value: 'kelvin',
        label: 'Kelvin',
        color: '#c026d3',
      },
      {
        value: 'custom-label',
        label: 'Custom Label',
        color: '#64748b',
      },
    ]);
  });
});
