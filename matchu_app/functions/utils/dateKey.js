const DATE_KEY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const FALLBACK_TIMEZONE = "Asia/Ho_Chi_Minh";

function normalizeTimezone(rawTimezone, fallback = FALLBACK_TIMEZONE) {
  const fallbackZone =
    typeof fallback === "string" && fallback.trim()
      ? fallback.trim()
      : FALLBACK_TIMEZONE;
  const timezone =
    typeof rawTimezone === "string" ? rawTimezone.trim() : "";

  if (!timezone) return fallbackZone;

  try {
    new Intl.DateTimeFormat("en-US", { timeZone: timezone });
    return timezone;
  } catch (_) {
    return fallbackZone;
  }
}

function getDateKeyForTimezone(date = new Date(), timeZone = FALLBACK_TIMEZONE) {
  const safeDate =
    date instanceof Date && !Number.isNaN(date.getTime()) ? date : new Date();
  const safeTimezone = normalizeTimezone(timeZone, FALLBACK_TIMEZONE);

  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: safeTimezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(safeDate);

  let year = "0000";
  let month = "00";
  let day = "00";

  for (const part of parts) {
    if (part.type === "year") year = part.value;
    if (part.type === "month") month = part.value;
    if (part.type === "day") day = part.value;
  }

  return `${year}-${month}-${day}`;
}

function isValidDateKey(value) {
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  if (!DATE_KEY_PATTERN.test(trimmed)) return false;

  const parsed = new Date(`${trimmed}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) return false;

  const [y, m, d] = trimmed.split("-").map((n) => Number(n));
  return (
    parsed.getUTCFullYear() === y &&
    parsed.getUTCMonth() + 1 === m &&
    parsed.getUTCDate() === d
  );
}

function resolveDateKey({ requestedDateKey, timeZone, now = new Date() } = {}) {
  if (isValidDateKey(requestedDateKey)) {
    return requestedDateKey.trim();
  }
  return getDateKeyForTimezone(now, timeZone);
}

module.exports = {
  FALLBACK_TIMEZONE,
  normalizeTimezone,
  getDateKeyForTimezone,
  isValidDateKey,
  resolveDateKey,
};
