require 'omniauth-eo-custom/version'
require 'omniauth/strategies/eo_custom'

module Omniauth
  module EOCustom
    OmniAuth.config.add_camelization 'eo_custom', 'EOCustom'
  end
end
