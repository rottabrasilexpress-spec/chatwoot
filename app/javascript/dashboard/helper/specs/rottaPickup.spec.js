import { describe, expect, it } from 'vitest';
import {
  isValidPickupDate,
  pickupDateLabel,
  splitPickupName,
  isPickupDateInWindow,
} from '../rottaPickup';

describe('pickup date display', () => {
  it('validates a real calendar date independently of the local timezone', () => {
    expect(isValidPickupDate('2026-11-20')).toBe(true);
    expect(isValidPickupDate('2026-02-29')).toBe(false);
    expect(isValidPickupDate('2028-02-29')).toBe(true);
    expect(isValidPickupDate('')).toBe(false);
  });

  it('validates a confirmation against both inclusive edges of the saved window', () => {
    expect(isPickupDateInWindow('2026-11-23', '2026-11-23', '2026-11-25')).toBe(
      true
    );
    expect(isPickupDateInWindow('2026-11-25', '2026-11-23', '2026-11-25')).toBe(
      true
    );
    expect(isPickupDateInWindow('2026-11-26', '2026-11-23', '2026-11-25')).toBe(
      false
    );
    expect(isPickupDateInWindow('2026-02-29', '2026-02-28', '2026-03-01')).toBe(
      false
    );
  });

  it('retains the year across a flexible range that crosses into a new year', () => {
    expect(pickupDateLabel('2026-11-20', '2026-11-25')).toBe(
      '20/11/2026 até 25/11'
    );
    expect(pickupDateLabel('2026-12-30', '2027-01-02')).toBe(
      '30/12/2026 até 02/01/2027'
    );
  });

  it('highlights the saved suffix while leaving unrelated characters in the name', () => {
    expect(splitPickupName('Cliente 2 20/11/2026', '20/11/2026')).toEqual([
      'Cliente 2',
      '20/11/2026',
    ]);
    expect(splitPickupName('Cliente 20', '20/11/2026')).toEqual([
      'Cliente 20',
      '',
    ]);
  });
});
