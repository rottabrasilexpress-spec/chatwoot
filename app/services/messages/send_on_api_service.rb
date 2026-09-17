require_dependency 'messages/uazapi_delivery'

class Messages::SendOnApiService < Base::SendOnChannelService
  include Messages::UazapiDelivery

  private

  def channel_class
    Channel::Api
  end
end
