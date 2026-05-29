// Branding callback stranice (popup koji korisnik vidi par sekundi nakon eID
// prijave). Sve dolazi iz env varijabli s generičkim defaultima — upstream
// server ostaje brand-neutralan, a konzument (npr. DOMOVINA.ai) ga brandira
// preko env-a (Coolify) bez forka. Vrijednosti se injectaju u callback.html
// kroz renderCallbackTemplate ({{brand*}} placeholderi).

const DEFAULTS = {
  brandName: '',
  brandLogoUrl: '',
  brandFontFamily:
    "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif",
  brandBgColor: '#f5f7fa',
  brandCardColor: '#ffffff',
  brandPrimaryColor: '#3b82f6',
  brandPrimaryHover: '#2563eb',
  brandSuccessColor: '#10b981',
  brandErrorColor: '#ef4444',
  brandTextColor: '#1f2937',
  brandMutedColor: '#6b7280',
  // Tekstovi (lokalizacija / brand glas). Default EN; konzument može HR.
  brandSuccessTitle: 'Authentication Successful',
  brandSuccessMessage: 'You can close this window and return to the app.',
  brandCloseButton: 'Close Window',
};

const ENV_MAP = {
  brandName: 'BRAND_NAME',
  brandLogoUrl: 'BRAND_LOGO_URL',
  brandFontFamily: 'BRAND_FONT_FAMILY',
  brandBgColor: 'BRAND_BG_COLOR',
  brandCardColor: 'BRAND_CARD_COLOR',
  brandPrimaryColor: 'BRAND_PRIMARY_COLOR',
  brandPrimaryHover: 'BRAND_PRIMARY_HOVER',
  brandSuccessColor: 'BRAND_SUCCESS_COLOR',
  brandErrorColor: 'BRAND_ERROR_COLOR',
  brandTextColor: 'BRAND_TEXT_COLOR',
  brandMutedColor: 'BRAND_MUTED_COLOR',
  brandSuccessTitle: 'BRAND_SUCCESS_TITLE',
  brandSuccessMessage: 'BRAND_SUCCESS_MESSAGE',
  brandCloseButton: 'BRAND_CLOSE_BUTTON',
};

export function getBranding() {
  const out = {};
  for (const [key, def] of Object.entries(DEFAULTS)) {
    const envVal = process.env[ENV_MAP[key]];
    out[key] = envVal && envVal.trim() !== '' ? envVal : def;
  }
  return out;
}
