import { describe, expect, it } from 'vitest';
import {
  ensureDashboardLocale,
  normalizeDashboardLocale,
} from './localeLoader';

describe('normalizeDashboardLocale', () => {
  it('keeps supported Chatwoot locale names', () => {
    expect(normalizeDashboardLocale('pt-BR')).toBe('pt_BR');
    expect(normalizeDashboardLocale('zh-TW')).toBe('zh_TW');
    expect(normalizeDashboardLocale('en')).toBe('en');
  });

  it('falls back to English for unknown locale names', () => {
    expect(normalizeDashboardLocale('xx-YY')).toBe('en');
    expect(normalizeDashboardLocale('')).toBe('en');
  });

  it('supports the unwrapped composer exposed to Options API components', async () => {
    const composer = {
      availableLocales: ['en', 'pt_BR'],
      locale: 'en',
      setLocaleMessage: vi.fn(),
    };

    await ensureDashboardLocale(composer, 'pt-BR');

    expect(composer.locale).toBe('pt_BR');
    expect(composer.setLocaleMessage).not.toHaveBeenCalled();
  });
});
