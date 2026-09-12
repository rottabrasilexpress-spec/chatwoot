require 'rails_helper'

RSpec.describe Messages::DictationTranscriptionService, type: :service do
  let(:account) { create(:account, audio_transcriptions: true) }
  let(:upload) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('public/audio/widget/ding.mp3'),
      'audio/mpeg'
    )
  end
  let(:service) { described_class.new(audio: upload, account: account) }
  let(:blob) { instance_double(ActiveStorage::Blob) } # rubocop:disable RSpec/VerifiedDoubles
  let(:speech_service) { instance_double(Llm::SpeechToTextService) } # rubocop:disable RSpec/VerifiedDoubles

  before do
    allow(Llm::SpeechToTextService).to receive(:available_for?).with(account).and_return(true)
    allow(Llm::SpeechToTextService).to receive(:too_large?).with(blob).and_return(false)
    allow(service).to receive(:create_blob).and_return(blob)
    allow(blob).to receive(:purge)
  end

  it 'transcribes Portuguese dictation without creating a message' do
    allow(Llm::SpeechToTextService).to receive(:new).with(
      blob: blob,
      account: account,
      language: 'pt',
      prompt: described_class::PROMPT
    ).and_return(speech_service)
    allow(speech_service).to receive(:perform).and_return('Olá, equipe')

    expect { service.perform }.not_to change(Message, :count)
    expect(service.perform).to eq(success: true, text: 'Olá, equipe')
    expect(blob).to have_received(:purge).at_least(:once)
  end

  it 'rejects unavailable transcription before creating a blob' do
    allow(Llm::SpeechToTextService).to receive(:available_for?).with(account).and_return(false)

    expect(service.perform).to eq(error: described_class::FEATURE_ERROR)
    expect(service).not_to have_received(:create_blob)
  end
end
