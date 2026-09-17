const localeModules = {
  ar: () => import('./locale/ar'),
  bg: () => import('./locale/bg'),
  ca: () => import('./locale/ca'),
  cs: () => import('./locale/cs'),
  da: () => import('./locale/da'),
  de: () => import('./locale/de'),
  el: () => import('./locale/el'),
  en: () => import('./locale/en'),
  es: () => import('./locale/es'),
  et: () => import('./locale/et'),
  fa: () => import('./locale/fa'),
  fi: () => import('./locale/fi'),
  fr: () => import('./locale/fr'),
  he: () => import('./locale/he'),
  hi: () => import('./locale/hi'),
  hu: () => import('./locale/hu'),
  id: () => import('./locale/id'),
  is: () => import('./locale/is'),
  it: () => import('./locale/it'),
  ja: () => import('./locale/ja'),
  ko: () => import('./locale/ko'),
  lt: () => import('./locale/lt'),
  lv: () => import('./locale/lv'),
  ml: () => import('./locale/ml'),
  nl: () => import('./locale/nl'),
  no: () => import('./locale/no'),
  pl: () => import('./locale/pl'),
  pt: () => import('./locale/pt'),
  pt_BR: () => import('./locale/pt_BR'),
  ro: () => import('./locale/ro'),
  ru: () => import('./locale/ru'),
  sk: () => import('./locale/sk'),
  sl: () => import('./locale/sl'),
  sr: () => import('./locale/sr'),
  sv: () => import('./locale/sv'),
  ta: () => import('./locale/ta'),
  th: () => import('./locale/th'),
  tr: () => import('./locale/tr'),
  uk: () => import('./locale/uk'),
  uz: () => import('./locale/uz'),
  vi: () => import('./locale/vi'),
  zh_CN: () => import('./locale/zh_CN'),
  zh_TW: () => import('./locale/zh_TW'),
};
const supportedLocales = new Set(Object.keys(localeModules));

export const normalizeDashboardLocale = locale => {
  const normalized = String(locale || '').replace('-', '_');
  return supportedLocales.has(normalized) ? normalized : 'en';
};

export const loadDashboardLocale = async locale => {
  const normalized = normalizeDashboardLocale(locale);
  const module = await localeModules[normalized]();
  return { locale: normalized, messages: module.default };
};

export const ensureDashboardLocale = async (i18n, requestedLocale) => {
  const composer = i18n?.global || i18n;
  const selected = normalizeDashboardLocale(requestedLocale);
  const loadedLocales =
    composer.availableLocales?.value || composer.availableLocales;
  if (!loadedLocales.includes(selected)) {
    const loaded = await loadDashboardLocale(selected);
    composer.setLocaleMessage(loaded.locale, loaded.messages);
  }
  if (composer.locale && typeof composer.locale === 'object') {
    composer.locale.value = selected;
  } else {
    composer.locale = selected;
  }
};

export const prepareDashboardI18n = async (i18n, requestedLocale) => {
  const selected = normalizeDashboardLocale(requestedLocale);
  const locales = selected === 'en' ? ['en'] : ['en', selected];
  const loaded = await Promise.all(locales.map(loadDashboardLocale));

  loaded.forEach(({ locale, messages }) => {
    i18n.global.setLocaleMessage(locale, messages);
  });
  await ensureDashboardLocale(i18n, selected);
};
