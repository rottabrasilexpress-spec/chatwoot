class SetRottaBrasilExpressBranding < ActiveRecord::Migration[7.1]
  BRANDING = {
    'INSTALLATION_NAME' => 'Rotta Brasil Express',
    'BRAND_NAME' => 'Rotta Brasil Express',
    'LOGO_THUMBNAIL' => '/brand-assets/rottabrasil-mark.png',
    'LOGO' => '/brand-assets/rottabrasil-logo.png',
    'LOGO_DARK' => '/brand-assets/rottabrasil-logo-dark.png'
  }.freeze

  def up
    BRANDING.each do |name, value|
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.save!
    end

    GlobalConfig.clear_cache
  end

  def down
    {
      'INSTALLATION_NAME' => 'Chatwoot',
      'BRAND_NAME' => 'Chatwoot',
      'LOGO_THUMBNAIL' => '/brand-assets/logo_thumbnail.svg',
      'LOGO' => '/brand-assets/logo.svg',
      'LOGO_DARK' => '/brand-assets/logo_dark.svg'
    }.each do |name, value|
      config = InstallationConfig.find_by(name: name)
      next unless config

      config.value = value
      config.save!
    end

    GlobalConfig.clear_cache
  end
end
