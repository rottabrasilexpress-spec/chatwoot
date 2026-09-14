class GlobalAiAssistant::AccessPolicy
  DEFAULT_OWNER_EMAIL = 'rottabrasilexpress@gmail.com'.freeze
  OWNER_SETTING = 'rotta_global_ai_owner_id'.freeze
  SHARED_USERS_SETTING = 'rotta_global_ai_shared_user_ids'.freeze

  class AccessDenied < StandardError; end

  class << self
    def ensure_allowed!(account:, user:)
      access = access_for(account: account, user: user)
      raise AccessDenied, 'O Pergunte para IA global ainda não está liberado para este agente.' unless access[:allowed]

      access
    end

    def access_for(account:, user:)
      owner_id = owner_id_for(account)
      owner_id = claim_default_owner!(account, user) if owner_id.blank? && default_owner?(user)
      shared_ids = shared_user_ids_for(account)
      is_owner = owner_id.present? && owner_id.to_i == user.id

      {
        allowed: is_owner || shared_ids.include?(user.id),
        owner: is_owner,
        owner_id: owner_id&.to_i,
        shared_user_ids: shared_ids,
        default_owner_email: DEFAULT_OWNER_EMAIL
      }
    end

    def shareable_agents(account)
      account.agents.order(:name).select(:id, :name, :email)
    end

    def update_shared_users!(account:, user:, user_ids:)
      access = ensure_allowed!(account: account, user: user)
      raise AccessDenied, 'Somente o proprietário pode espelhar o assistente.' unless access[:owner]

      allowed_ids = account.agents.where(id: Array(user_ids).map(&:to_i)).pluck(:id)
      settings = (account.settings || {}).deep_dup
      settings[SHARED_USERS_SETTING] = allowed_ids
      account.update!(settings: settings)
      access_for(account: account.reload, user: user)
    end

    private

    def owner_id_for(account)
      account.settings.to_h[OWNER_SETTING].presence
    end

    def shared_user_ids_for(account)
      Array(account.settings.to_h[SHARED_USERS_SETTING]).filter_map do |value|
        Integer(value, exception: false)
      end
    end

    def default_owner?(user)
      user&.email.to_s.casecmp?(DEFAULT_OWNER_EMAIL)
    end

    def claim_default_owner!(account, user)
      account.with_lock do
        account.reload
        settings = (account.settings || {}).deep_dup
        settings[OWNER_SETTING] ||= user.id
        account.update!(settings: settings)
        settings[OWNER_SETTING]
      end
    end
  end
end
