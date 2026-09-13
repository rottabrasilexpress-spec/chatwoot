import { describe, expect, it } from 'vitest';
import {
  buildGoogleDirectionsUrl,
  buildGooglePlaceUrl,
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
});
