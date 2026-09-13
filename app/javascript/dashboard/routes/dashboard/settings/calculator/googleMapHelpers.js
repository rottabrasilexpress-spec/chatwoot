const GOOGLE_MAPS_BASE_URL = 'https://www.google.com/maps';

export const buildGooglePlaceUrl = location => {
  const value = String(location || '').trim();
  return value
    ? `${GOOGLE_MAPS_BASE_URL}/search/?api=1&query=${encodeURIComponent(value)}`
    : 'https://maps.google.com';
};

export const buildGoogleDirectionsUrl = (origin, destination) => {
  const points = [origin, destination].map(value => String(value || '').trim());
  return points.every(Boolean)
    ? `${GOOGLE_MAPS_BASE_URL}/dir/${encodeURIComponent(points[0])}/${encodeURIComponent(points[1])}`
    : 'https://maps.google.com';
};
