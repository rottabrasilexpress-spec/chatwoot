export const CLOSED_PICKUP_LABEL = 'clientes-fechados';
export const PICKUP_SUFFIX_KEY = 'rotta_pickup_name_suffix';

export const isValidPickupDate = value => {
  if (!/^[1-9]\d{3}-\d{2}-\d{2}$/.test(value || '')) return false;
  const date = new Date(value + 'T00:00:00Z');
  return (
    !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value
  );
};

const dateParts = value => {
  const [year, month, day] = value.split('-');
  return {
    year,
    short: day + '/' + month,
    full: day + '/' + month + '/' + year,
  };
};

export const isPickupDateInWindow = (date, start, end) =>
  isValidPickupDate(date) &&
  isValidPickupDate(start) &&
  isValidPickupDate(end) &&
  start < end &&
  date >= start &&
  date <= end;

export const isFlexiblePickup = pickup =>
  Boolean(pickup?.ends_on && pickup.ends_on > pickup.starts_on);

export const pickupDateLabel = (start, end) => {
  if (!isValidPickupDate(start)) return '';
  const first = dateParts(start);
  if (!isValidPickupDate(end) || end === start) return first.full;
  const last = dateParts(end);
  return (
    first.full + ' até ' + (last.year === first.year ? last.short : last.full)
  );
};

export const splitPickupName = (name, suffix, allowLegacy = false) => {
  const fullName = String(name || '');
  const date =
    suffix ||
    (allowLegacy &&
      fullName.match(
        /\s+(\d{2}\/\d{2}\/\d{4}(?:\s+até\s+\d{2}\/\d{2}(?:\/\d{4})?)?)$/i
      )?.[1]);
  if (!date || !fullName.endsWith(' ' + date)) return [fullName, ''];
  return [fullName.slice(0, -(date.length + 1)), date];
};

const compareDate = (a, b, descending) => {
  if (a === b) return 0;
  if (!a) return 1;
  if (!b) return -1;
  return (a < b ? -1 : 1) * (descending ? -1 : 1);
};

export const comparePickupSchedules = (a, b, descending) =>
  compareDate(
    a.rotta_pickup?.starts_on,
    b.rotta_pickup?.starts_on,
    descending
  ) ||
  compareDate(
    a.rotta_pickup?.delivery_on,
    b.rotta_pickup?.delivery_on,
    descending
  ) ||
  a.id - b.id;
