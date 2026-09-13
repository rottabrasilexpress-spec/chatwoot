export const calculatorBackgroundPresets = [
  { id: 'amber', label: 'Âmbar suave', color: '#fff7ed' },
  { id: 'blue', label: 'Azul névoa', color: '#eff6ff' },
  { id: 'teal', label: 'Verde água', color: '#f0fdfa' },
  { id: 'rose', label: 'Rosa claro', color: '#fdf2f8' },
  { id: 'violet', label: 'Lavanda', color: '#f5f3ff' },
  { id: 'slate', label: 'Cinza azulado', color: '#f8fafc' },
];

const normalizeChannel = value => {
  const channel = Number.parseInt(value, 16);
  return Number.isNaN(channel) ? 0 : channel / 255;
};

export const normalizeHexColor = value => {
  const color = String(value || '')
    .trim()
    .toLowerCase();
  if (/^#[0-9a-f]{3}$/i.test(color)) {
    return `#${color
      .slice(1)
      .split('')
      .map(channel => `${channel}${channel}`)
      .join('')}`;
  }
  return /^#[0-9a-f]{6}$/i.test(color) ? color : null;
};

export const getColorLuminance = color => {
  const normalized = normalizeHexColor(color) || '#ffffff';
  const channels = [1, 3, 5].map(index =>
    normalizeChannel(normalized.slice(index, index + 2))
  );
  const linearChannels = channels.map(channel =>
    channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
  );

  return (
    linearChannels[0] * 0.2126 +
    linearChannels[1] * 0.7152 +
    linearChannels[2] * 0.0722
  );
};

export const getContrastRatio = (foreground, background) => {
  const foregroundLuminance = getColorLuminance(foreground);
  const backgroundLuminance = getColorLuminance(background);
  const lighter = Math.max(foregroundLuminance, backgroundLuminance);
  const darker = Math.min(foregroundLuminance, backgroundLuminance);

  return (lighter + 0.05) / (darker + 0.05);
};

export const getReadableTextColor = background => {
  const darkText = '#172033';
  const lightText = '#ffffff';
  return getContrastRatio(darkText, background) >=
    getContrastRatio(lightText, background)
    ? darkText
    : lightText;
};
