class BrandRottaWoot < ActiveRecord::Migration[7.1]
  BRANDING = {
    'INSTALLATION_NAME' => 'RottaWoot',
    'BRAND_NAME' => 'RottaWoot',
    'LOGO_THUMBNAIL' => '/brand-assets/rottabrasil-mark-transparent.png',
    'LOGO' => '/brand-assets/rottabrasil-logo.png',
    'LOGO_DARK' => '/brand-assets/rottabrasil-logo-dark.png'
  }.freeze

  PREVIOUS_BRANDING = {
    'INSTALLATION_NAME' => 'Chatwoot',
    'BRAND_NAME' => 'Chatwoot',
    'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
    'LOGO' => '/brand-assets/logo.svg',
    'LOGO_DARK' => '/brand-assets/logo_dark.svg'
  }.freeze

  def up
    apply_branding(BRANDING)
  end

  def down
    apply_branding(PREVIOUS_BRANDING)
  end

  private

  def apply_branding(branding)
    branding.each do |name, value|
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.save!
    end

    GlobalConfig.clear_cache
  end
end
