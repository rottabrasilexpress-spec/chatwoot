require 'rails_helper'

RSpec.describe RottaArchivedConversationRetentionJob, type: :job do
  let(:rotta_account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:cutoff) { Time.current - described_class::RETENTION_PERIOD }

  around do |example|
    original_account_id = ENV.fetch('ROTTABRASIL_CHATWOOT_ACCOUNT_ID', nil)
    ENV['ROTTABRASIL_CHATWOOT_ACCOUNT_ID'] = rotta_account.id.to_s
    example.run
  ensure
    if original_account_id
      ENV['ROTTABRASIL_CHATWOOT_ACCOUNT_ID'] = original_account_id
    else
      ENV.delete('ROTTABRASIL_CHATWOOT_ACCOUNT_ID')
    end
  end

  it 'uses the housekeeping queue' do
    expect(described_class.queue_name).to eq('housekeeping')
  end

  it 'deletes only old resolved Rotta conversations' do
    old_archived = create(
      :conversation,
      account: rotta_account,
      status: :resolved,
      label_list: ['arquivado'],
      last_activity_at: cutoff + 1.day
    )
    old_archived.update_columns(
      additional_attributes: { 'rotta_archived_at' => (cutoff - 1.day).iso8601 },
      last_activity_at: cutoff + 1.day
    )
    old_resolved_without_archive_label = create(
      :conversation,
      account: rotta_account,
      status: :resolved,
      last_activity_at: cutoff - 1.day
    )
    old_resolved_without_archive_label.update_column(:last_activity_at, cutoff - 1.day)
    old_legacy_archived = create(
      :conversation,
      account: rotta_account,
      status: :resolved,
      label_list: ['arquivado'],
      last_activity_at: cutoff - 1.day
    )
    old_legacy_archived.update_columns(
      additional_attributes: {},
      last_activity_at: cutoff - 1.day
    )
    recent_archived = create(
      :conversation,
      account: rotta_account,
      status: :resolved,
      label_list: ['arquivado'],
      last_activity_at: cutoff + 1.day
    )
    recent_archived.update_columns(
      additional_attributes: { 'rotta_archived_at' => (cutoff + 1.day).iso8601 },
      last_activity_at: cutoff + 1.day
    )
    newly_archived_with_old_activity = create(
      :conversation,
      account: rotta_account,
      status: :resolved,
      label_list: ['arquivado'],
      last_activity_at: cutoff - 1.day
    )
    newly_archived_with_old_activity.update_columns(
      additional_attributes: { 'rotta_archived_at' => Time.current.iso8601 },
      last_activity_at: cutoff - 1.day
    )
    old_numbered_archived = create(
      :conversation,
      account: rotta_account,
      status: :resolved,
      label_list: ['[1] arquivado'],
      last_activity_at: cutoff + 1.day
    )
    old_numbered_archived.update_columns(
      additional_attributes: { 'rotta_archived_at' => (cutoff - 1.day).iso8601 },
      last_activity_at: cutoff + 1.day
    )
    old_open = create(
      :conversation,
      account: rotta_account,
      status: :open,
      last_activity_at: cutoff - 1.day
    )
    old_open.update_column(:last_activity_at, cutoff - 1.day)
    old_other_account = create(
      :conversation,
      account: other_account,
      status: :resolved,
      label_list: ['arquivado'],
      last_activity_at: cutoff - 1.day
    )
    old_other_account.update_columns(
      additional_attributes: { 'rotta_archived_at' => (cutoff - 1.day).iso8601 },
      last_activity_at: cutoff - 1.day
    )

    described_class.perform_now

    expect { old_archived.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(old_resolved_without_archive_label.reload).to be_present
    expect { old_legacy_archived.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(recent_archived.reload).to be_present
    expect(newly_archived_with_old_activity.reload).to be_present
    expect { old_numbered_archived.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(old_open.reload).to be_present
    expect(old_other_account.reload).to be_present
  end
end
