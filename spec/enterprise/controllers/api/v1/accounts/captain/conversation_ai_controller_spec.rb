require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Captain::ConversationAiActions', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/captain/conversation_ai/actions" }
  let(:profile_endpoint) { "/api/v1/accounts/#{account.id}/captain/conversation_ai/profile" }

  it 'records the actor, target, state transition and result in the audit log' do
    expect do
      post endpoint,
           params: {
             conversation_id: conversation.display_id,
             action: 'set_status',
             status: 'pending'
           },
           headers: admin.create_new_auth_token,
           as: :json
    end.to change(Enterprise::AuditLog, :count).by(1)

    expect(response).to have_http_status(:success)

    audit = Enterprise::AuditLog.last
    expect(audit.action).to eq('conversation_ai_action')
    expect(audit.auditable).to eq(conversation)
    expect(audit.user).to eq(admin)
    expect(audit.request_uuid).to be_present
    expect(audit.audited_changes).to include(
      'source' => 'conversation_ai',
      'action' => 'set_status',
      'conversation_display_id' => conversation.display_id,
      'before' => include('status' => 'open'),
      'after' => include('status' => 'pending'),
      'result' => include('status' => 'pending')
    )
  end

  it 'does not allow an unauthenticated action' do
    post endpoint,
         params: {
           conversation_id: conversation.display_id,
           action: 'set_status',
           status: 'pending'
         },
         as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'accepts a human-readable label name and removes the stored label slug' do
    create(:label, account: account, title: 'caio-atencao')

    post endpoint,
         params: {
           conversation_id: conversation.display_id,
           action: 'add_label',
           label: 'Caio Atenção'
         },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload.label_list).to include('caio-atencao')

    post endpoint,
         params: {
           conversation_id: conversation.display_id,
           action: 'remove_label',
           label: 'Caio Atenção'
         },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.reload.label_list).not_to include('caio-atencao')
  end

  it 'updates the current contact name and records the action' do
    post endpoint,
         params: {
           conversation_id: conversation.display_id,
           action: 'update_contact_name',
           name: 'Luciana'
         },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.contact.reload.name).to eq('Luciana')
    expect(Enterprise::AuditLog.last.audited_changes).to include(
      'action' => 'update_contact_name',
      'before' => include('contact_name' => be_present),
      'after' => include('contact_name' => 'Luciana')
    )
  end

  it 'fills the move profile from the current conversation and persists only evidenced values' do
    message = conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      sender: conversation.contact,
      message_type: :incoming,
      content: 'Meu nome é Luciana. A mudança será de Brasília para Salvador em 25/10/2026.'
    )
    response_body = {
      'contact_name' => 'Luciana',
      'profile' => {
        'origin' => 'Brasília',
        'destination' => 'Salvador',
        'move_date' => '25/10/2026',
        'budget_value' => nil,
        'items' => nil,
        'observations' => nil,
        'helpers_origin' => nil,
        'helpers_destination' => nil,
        'assembly_items' => nil,
        'disassembly_items' => nil
      },
      'evidence' => {
        'contact_name' => { 'message_id' => message.id, 'quote' => 'Meu nome é Luciana' },
        'origin' => { 'message_id' => message.id, 'quote' => 'de Brasília' },
        'destination' => { 'message_id' => message.id, 'quote' => 'para Salvador' },
        'move_date' => { 'message_id' => message.id, 'quote' => '25/10/2026' }
      }
    }
    client = instance_double(GlobalAiAssistant::OpenRouterClient)
    allow(GlobalAiAssistant::ProviderConfig).to receive(:api_key).and_return('test-key')
    allow(GlobalAiAssistant::OpenRouterClient).to receive(:new).and_return(client)
    allow(client).to receive(:call).and_return(response_body.to_json)

    post profile_endpoint,
         params: { conversation_id: conversation.display_id },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.contact.reload.name).to eq('Luciana')
    expect(conversation.contact.custom_attributes['rotta_move_profile']).to include(
      'origin' => 'Brasília',
      'destination' => 'Salvador',
      'move_date' => '25/10/2026'
    )
    expect(JSON.parse(response.body)).to include('ok' => true, 'changed_fields' => include('origin', 'destination'))
  end

  it 'does not replace an existing profile value when the model evidence is not in the conversation' do
    conversation.contact.update!(custom_attributes: {
      'rotta_move_profile' => { 'origin' => 'São Paulo' }
    })
    message = conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      sender: conversation.contact,
      message_type: :incoming,
      content: 'Ainda estou verificando a data da mudança.'
    )
    client = instance_double(GlobalAiAssistant::OpenRouterClient)
    allow(GlobalAiAssistant::ProviderConfig).to receive(:api_key).and_return('test-key')
    allow(GlobalAiAssistant::OpenRouterClient).to receive(:new).and_return(client)
    allow(client).to receive(:call).and_return({
      'contact_name' => nil,
      'profile' => { 'origin' => 'Rio de Janeiro' },
      'evidence' => { 'origin' => { 'message_id' => message.id, 'quote' => 'Rio de Janeiro' } }
    }.to_json)

    post profile_endpoint,
         params: { conversation_id: conversation.display_id },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.contact.reload.custom_attributes['rotta_move_profile']['origin']).to eq('São Paulo')
    expect(JSON.parse(response.body)).to include('changed_fields' => [])
  end

  it 'retries once when the model returns an empty JSON response' do
    message = conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      sender: conversation.contact,
      message_type: :incoming,
      content: 'A mudança será de Campinas para Santos.'
    )
    valid_response = {
      'contact_name' => nil,
      'profile' => { 'origin' => 'Campinas', 'destination' => 'Santos' },
      'evidence' => {
        'origin' => { 'message_id' => message.id, 'quote' => 'de Campinas' },
        'destination' => { 'message_id' => message.id, 'quote' => 'para Santos' }
      }
    }.to_json
    client = instance_double(GlobalAiAssistant::OpenRouterClient)
    allow(GlobalAiAssistant::ProviderConfig).to receive(:api_key).and_return('test-key')
    allow(GlobalAiAssistant::OpenRouterClient).to receive(:new).and_return(client)
    allow(client).to receive(:call).and_return('', valid_response)

    post profile_endpoint,
         params: { conversation_id: conversation.display_id },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(JSON.parse(response.body)).to include('changed_fields' => include('origin', 'destination'))
  end

  it 'recovers explicit inventory, budget and service markers from a structured quote' do
    message = conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      sender: conversation.contact,
      message_type: :incoming,
      content: <<~TEXT
        ORÇAMENTO FINAL
        ORIGEM: Patos, PB, Brasil
        DESTINO: Aracruz, ES, Brasil
        COLETA: 30/10/2026
        • [01] Geladeira
        • [02] Espelhos
        • [03] Caixas
        Valor: ✅ R$ 3.655,37
        Carga (origem): Por conta do cliente
        Descarga (destino): Por conta do cliente
        DESMONTAGEM: ❌ NÃO
        MONTAGEM: ❌ NÃO
      TEXT
    )
    empty_profile = {
      'contact_name' => nil,
      'profile' => ConversationAi::ProfileService::PROFILE_FIELDS.index_with { nil },
      'evidence' => {}
    }
    client = instance_double(GlobalAiAssistant::OpenRouterClient)
    allow(GlobalAiAssistant::ProviderConfig).to receive(:api_key).and_return('test-key')
    allow(GlobalAiAssistant::OpenRouterClient).to receive(:new).and_return(client)
    allow(client).to receive(:call).and_return(empty_profile.to_json)

    post profile_endpoint,
         params: { conversation_id: conversation.display_id },
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    profile = conversation.contact.reload.custom_attributes['rotta_move_profile']
    expect(profile).to include(
      'origin' => 'Patos, PB, Brasil',
      'destination' => 'Aracruz, ES, Brasil',
      'move_date' => '30/10/2026',
      'budget_value' => 'R$ 3.655,37',
      'helpers_origin' => 0,
      'helpers_destination' => 0,
      'assembly_items' => '❌ NÃO',
      'disassembly_items' => '❌ NÃO'
    )
    expect(profile['items']).to include('Geladeira', 'Espelhos', 'Caixas')
    expect(JSON.parse(response.body)['changed_fields']).to include(
      'origin', 'destination', 'move_date', 'budget_value', 'items',
      'helpers_origin', 'helpers_destination', 'assembly_items', 'disassembly_items'
    )
  end
end
