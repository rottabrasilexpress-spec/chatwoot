const GOOGLE_MAPS_BASE_URL = 'https://www.google.com/maps';

/* eslint-disable no-bitwise, no-plusplus */

export const decodeGooglePolyline = encoded => {
  if (!encoded) return [];

  const points = [];
  let index = 0;
  let latitude = 0;
  let longitude = 0;

  while (index < encoded.length) {
    let shift = 0;
    let result = 0;
    let byte;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    latitude += result & 1 ? ~(result >> 1) : result >> 1;

    shift = 0;
    result = 0;
    do {
      byte = encoded.charCodeAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    longitude += result & 1 ? ~(result >> 1) : result >> 1;
    points.push({ lat: latitude / 1e5, lng: longitude / 1e5 });
  }

  return points;
};

/* eslint-enable no-bitwise, no-plusplus */

export const getGoogleMapEndpoints = encoded => {
  const points = decodeGooglePolyline(encoded);
  if (points.length < 2) return null;

  return {
    origin: points[0],
    destination: points[points.length - 1],
  };
};

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
