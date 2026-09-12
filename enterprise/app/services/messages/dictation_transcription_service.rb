class Messages::DictationTranscriptionService
  FEATURE_ERROR = 'Audio transcription is not available for this account'.freeze
  SIZE_ERROR = 'Audio file exceeds the transcription limit'.freeze
  INPUT_ERROR = 'A valid audio file is required'.freeze

  ALLOWED_CONTENT_TYPES = %r{\Aaudio/}.freeze
  LANGUAGE = 'pt-BR'.freeze
  PROMPT = 'Transcreva em português do Brasil, preservando nomes próprios, cidades, estados, números e valores monetários.'.freeze

  pattr_initialize [:audio!, :account!]

  def perform
    return { error: INPUT_ERROR } unless valid_audio?
    return { error: FEATURE_ERROR } unless Llm::SpeechToTextService.available_for?(account)

    blob = create_blob
    return { error: SIZE_ERROR } if Llm::SpeechToTextService.too_large?(blob)

    text = Llm::SpeechToTextService.new(
      blob: blob,
      account: account,
      language: LANGUAGE,
      prompt: PROMPT
    ).perform.to_s.strip

    return { error: 'No speech detected' } if text.blank?

    { success: true, text: text }
  rescue Faraday::UnauthorizedError
    { error: FEATURE_ERROR }
  ensure
    purge_blob
  end

  private

  attr_reader :blob

  def valid_audio?
    audio.respond_to?(:tempfile) &&
      audio.tempfile.present? &&
      audio.tempfile.respond_to?(:size) &&
      audio.tempfile.size.positive? &&
      audio.content_type.to_s.match?(ALLOWED_CONTENT_TYPES)
  end

  def create_blob
    audio.tempfile.rewind
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: audio.tempfile,
      filename: audio.original_filename.presence || 'dictation.webm',
      content_type: audio.content_type,
      metadata: { 'purpose' => 'rotta_dictation' }
    )
  end

  def purge_blob
    blob&.purge
  rescue StandardError => e
    Rails.logger.warn("[RottaDictation] temporary blob cleanup failed: #{e.class}")
  end
end
