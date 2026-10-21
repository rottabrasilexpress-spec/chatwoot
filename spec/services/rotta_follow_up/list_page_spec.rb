require 'rails_helper'

RSpec.describe RottaFollowUp::ListPage do
  let(:now) { Time.iso8601('2026-10-20T15:00:00Z') }
  let(:jobs) do
    1088.times.map do |index|
      { 'job_id' => "job-#{index}", 'conversation_id' => index.to_s, 'current_label' => 'primeiro-contato',
        'customer_name' => "Cliente #{index}", 'phone' => "551199#{index.to_s.rjust(5, '0')}",
        'scheduled_at' => (now + index.minutes).iso8601, 'status' => index < 6 ? 'failed_send' : 'pending' }
    end
  end
  let(:body) { { 'jobs' => jobs, 'dispatch_window' => { 'start' => '07:00', 'end' => '21:00', 'timezone' => 'America/Sao_Paulo' } } }

  it 'bounds every page without losing globally counted or future jobs' do
    first = described_class.new(body, { 'page' => 1, 'per_page' => 25 }, now: now).call
    last = described_class.new(body, { 'page' => 44, 'per_page' => 25 }, now: now).call
    expect(first['jobs'].length).to eq(25)
    expect(first.dig('summary', 'all')).to eq(1088)
    expect(first.dig('summary', 'failures')).to eq(6)
    expect(last['jobs'].length).to eq(13)
    expect(last['jobs'].last['job_id']).to eq('job-1087')
    expect(first['jobs'] & last['jobs']).to be_empty
  end

  it 'searches the whole queue, not just the current page' do
    result = described_class.new(body, { 'page' => 1, 'search' => 'Cliente 1087' }, now: now).call
    expect(result['jobs'].map { |job| job['job_id'] }).to eq(['job-1087'])
    expect(result.dig('summary', 'all')).to eq(1088)
  end

  it 'excludes history and independently paginates actual failures' do
    body['jobs'] << jobs.first.merge('status' => 'sent_history', 'job_id' => 'history')
    result = described_class.new(body, { 'page' => 2, 'per_page' => 2, 'panel' => 'failures', 'panel_page' => 3 }, now: now).call
    expect(result.dig('summary', 'all')).to eq(1088)
    expect(result['panel_jobs'].map { |job| job['job_id'] }).to eq(%w[job-4 job-5])
    expect(result.dig('panel_pagination', 'total')).to eq(6)
  end

  it 'clamps oversized page requests and page size' do
    result = described_class.new(body, { 'page' => 9999, 'per_page' => 10000 }, now: now).call
    expect(result.dig('pagination', 'per_page')).to eq(50)
    expect(result.dig('pagination', 'page')).to eq(22)
  end

  it 'classifies overdue outside the real sending window in Sao Paulo' do
    closed = Time.iso8601('2026-10-21T01:00:00Z')
    result = described_class.new(body, { 'page' => 1, 'panel' => 'overdue' }, now: closed).call
    expect(result.dig('summary', 'overdue')).to be_positive
    expect(result['panel_jobs']).not_to be_empty
  end
end
