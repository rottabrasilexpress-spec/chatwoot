class Api::V1::Accounts::Conversations::AudioTranscriptionsController < Api::V1::Accounts::Conversations::BaseController
  def create
    result = Messages::DictationTranscriptionService.new(
      audio: params[:audio],
      account: Current.account
    ).perform

    if result[:success]
      render json: { text: result[:text] }
    else
      render json: { error: result[:error] }, status: error_status(result[:error])
    end
  end

  private

  def error_status(error)
    return :forbidden if error == Messages::DictationTranscriptionService::FEATURE_ERROR
    return :payload_too_large if error == Messages::DictationTranscriptionService::SIZE_ERROR

    :unprocessable_entity
  end
end
