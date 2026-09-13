import {
  calculatorBackgroundPresets,
  getColorLuminance,
  getContrastRatio,
  getReadableTextColor,
  normalizeHexColor,
} from './calculatorLayout';

describe('calculatorLayout', () => {
  it('normalizes preset and custom hex colors', () => {
    expect(normalizeHexColor('#abc')).toBe('#aabbcc');
    expect(normalizeHexColor('#FFF7ED')).toBe('#fff7ed');
    expect(normalizeHexColor('not-a-color')).toBeNull();
  });

  it('keeps every curated pastel readable with dark interface text', () => {
    calculatorBackgroundPresets.forEach(({ color }) => {
      expect(getReadableTextColor(color)).toBe('#172033');
      expect(getContrastRatio('#172033', color)).toBeGreaterThan(4.5);
    });
  });

  it('switches to light toolbar text for a dark custom background', () => {
    expect(getReadableTextColor('#172033')).toBe('#ffffff');
    expect(getColorLuminance('#000000')).toBe(0);
    expect(getContrastRatio('#ffffff', '#172033')).toBeGreaterThan(15);
  });
});
