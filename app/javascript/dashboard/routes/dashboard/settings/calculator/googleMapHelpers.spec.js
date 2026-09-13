import { describe, expect, it } from 'vitest';
import {
  buildGoogleDirectionsUrl,
  buildGooglePlaceUrl,
  decodeGooglePolyline,
  getGoogleMapEndpoints,
} from './googleMapHelpers';

describe('googleMapHelpers', () => {
  it('creates a Google place link for a location photo/search action', () => {
    expect(buildGooglePlaceUrl('Palotina - PR')).toBe(
      'https://www.google.com/maps/search/?api=1&query=Palotina%20-%20PR'
    );
  });

  it('creates a directions link only when both route endpoints exist', () => {
    expect(buildGoogleDirectionsUrl('Palotina - PR', 'Linhares - ES')).toBe(
      'https://www.google.com/maps/dir/Palotina%20-%20PR/Linhares%20-%20ES'
    );
    expect(buildGoogleDirectionsUrl('Palotina - PR', '')).toBe(
      'https://maps.google.com'
    );
  });

  it('decodes route endpoints for map markers without inventing coordinates', () => {
    const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

    expect(decodeGooglePolyline(encoded)).toEqual([
      { lat: 38.5, lng: -120.2 },
      { lat: 40.7, lng: -120.95 },
      { lat: 43.252, lng: -126.453 },
    ]);
    expect(getGoogleMapEndpoints(encoded)).toEqual({
      origin: { lat: 38.5, lng: -120.2 },
      destination: { lat: 43.252, lng: -126.453 },
    });
    expect(getGoogleMapEndpoints('')).toBeNull();
  });

  it('keeps a place link usable when only one location is available', () => {
    expect(buildGooglePlaceUrl('  Palotina - PR  ')).toBe(
      'https://www.google.com/maps/search/?api=1&query=Palotina%20-%20PR'
    );
    expect(buildGooglePlaceUrl('')).toBe('https://maps.google.com');
  });
});
