class RottaFollowUp::ListPage
  CONTACT = %w[primeiro-contato segundo-contato terceiro-contato ultimo-contato].freeze
  BUDGET = %w[orcamento-feito orcamento-tentativa-2 orcamento-tentativa-3 orcamento-tentativa-4 orcamento-5-dias orcamento-10-dias orcamento-15-dias].freeze
  ALIASES = { 'contato-instantaneo' => 'primeiro-contato', 'orcamento-instantaneo' => 'orcamento-feito',
              'quarto-contato' => 'ultimo-contato', 'clientes-fechados' => 'arquivado' }.freeze
  NEXT_STAGE = CONTACT.zip(CONTACT.drop(1) + ['arquivado']).to_h.merge(
    BUDGET.first(4).zip(BUDGET.first(4).drop(1) + ['arquivado']).to_h
  ).merge(BUDGET.drop(4).index_with { 'orcamento-feito' }).freeze
  STAGE_NAMES = {
    'primeiro-contato' => 'Primeiro contato', 'segundo-contato' => 'Segundo contato', 'terceiro-contato' => 'Terceiro contato',
    'ultimo-contato' => 'Quarto contato', 'orcamento-feito' => 'Orçamento feito', 'orcamento-tentativa-2' => 'Segundo orçamento',
    'orcamento-tentativa-3' => 'Terceiro orçamento', 'orcamento-tentativa-4' => 'Quarto orçamento'
  }.freeze

  def initialize(body, options, now: Time.current)
    @body = body
    @options = options
    @now = now
    @per_page = [[options['per_page'].to_i, 1].max, 50].min
    @per_page = 25 unless options.key?('per_page')
  end

  def call
    seen = Set.new
    rows = Array(@body['jobs']).filter_map do |job|
      next if %w[sent_history history_only].include?(job['status'])

      stage = canonical(job['current_label'].presence || job['source_label'])
      key = [job['conversation_id'].presence || job['job_id'], stage]
      next unless seen.add?(key)

      trail = trail_for(job, stage)
      due = effective_at(job)
      scheduled = parse_time(job['scheduled_at'])
      overdue = trail.present? && scheduled && scheduled <= @now && due && due > @now
      zone = Time.find_zone!(job['timezone'].presence || @body['timezone'].presence || 'America/Sao_Paulo')
      today = trail.present? && !overdue && due && due.in_time_zone(zone).to_date == @now.in_time_zone(zone).to_date
      { job: job, stage: stage, trail: trail, due: due, overdue: !!overdue, today: !!today }
    end
    rows.sort_by! { |row| [row[:due]&.to_f || Float::INFINITY, row[:stage], row[:job]['job_id'].to_s] }
    active = rows.select { |row| row[:trail] }
    failures = rows.select { |row| row[:job]['status'].to_s == 'sync_failed' || row[:job]['status'].to_s.start_with?('failed') }
    overdue = active.select { |row| row[:overdue] }
    counts = rows.reject { |row| row[:stage].blank? || row[:stage] == 'arquivado' }.group_by { |row| row[:stage] }.transform_values(&:length)
    summary = {
      'all' => active.length, 'today' => active.count { |row| row[:today] }, 'overdue' => overdue.length, 'failures' => failures.length,
      'counts' => counts, 'views' => { 'all' => active.length, 'contact' => active.count { |row| row[:trail] == 'contact' },
                                     'budget' => active.count { |row| row[:trail] == 'budget' } }
    }
    query = normalized(@options['search'].to_s.first(200))
    digits = query.gsub(/\D/, '')
    view = @options['view'].presence || 'all'
    stage_filter = @options['stage'].presence || 'all'
    filtered = active.select do |row|
      next false unless view == 'all' || row[:trail] == view
      next false unless stage_filter == 'all' || row[:stage] == canonical(stage_filter)

      job = row[:job]
      next_stage = canonical(job['next_label'].presence || NEXT_STAGE[row[:stage]])
      content = [job['customer_name'], job['phone'], row[:stage], next_stage,
                 STAGE_NAMES[row[:stage]], STAGE_NAMES[next_stage], @body.dig('labels', row[:stage]),
                 @body.dig('labels', next_stage)].compact.join(' ')
      query.empty? || normalized(content).include?(query) || (digits.length >= 3 && job['phone'].to_s.gsub(/\D/, '').include?(digits))
    end
    main = page(filtered, @options['page'])
    panel_rows = @options['panel'] == 'overdue' ? overdue : failures
    panel = page(panel_rows, @options['panel_page'])
    @body.merge('jobs' => main[:jobs], 'pagination' => main[:pagination], 'summary' => summary,
                'panel_jobs' => @options['panel'].present? ? panel[:jobs] : [], 'panel_pagination' => panel[:pagination])
  end

  private

  def page(rows, requested_page)
    total_pages = [(rows.length.to_f / @per_page).ceil, 1].max
    number = [[requested_page.to_i, 1].max, total_pages].min
    {
      jobs: rows.slice((number - 1) * @per_page, @per_page).to_a.map { |row| row[:job] },
      pagination: { 'page' => number, 'per_page' => @per_page, 'total' => rows.length, 'total_pages' => total_pages }
    }
  end

  def normalized(value)
    I18n.transliterate(value.to_s).downcase
  end

  def canonical(value)
    stage = normalized(value.to_s.gsub(/[✅❌🫶💰🤝]/, '')).sub(/\A\[\d+\]\s*/, '').strip.gsub(/\s+/, '-')
    ALIASES.fetch(stage, stage)
  end

  def trail_for(job, stage)
    return nil if stage == 'arquivado'

    [stage, canonical(job['source_label']), canonical(job['next_label'])].each do |candidate|
      return 'contact' if CONTACT.include?(candidate)
      return 'budget' if BUDGET.include?(candidate)
    end
    history = %w[history sent_history dispatched_labels follow_up_history].flat_map do |key|
      Array(job[key]).map { |item| canonical(item.is_a?(Hash) ? item['label'] || item['slug'] || item['name'] : item) }
    end
    return 'budget' if (history & BUDGET).any?
    return 'contact' if (history & CONTACT).any?

    nil
  end

  def effective_at(job)
    scheduled = parse_time(job['scheduled_at'])
    return nil unless scheduled

    config = job['dispatch_window'] || @body['dispatch_window'] || @body.dig('meta', 'dispatch_window') || {}
    zone = Time.find_zone!(job['timezone'].presence || config['timezone'].presence || @body['timezone'].presence || 'America/Sao_Paulo')
    start_hour, start_minute = (config['start'].presence || '06:00').split(':').map(&:to_i)
    end_hour, end_minute = (config['end'].presence || '23:00').split(':').map(&:to_i)
    target = [scheduled, @now].max.in_time_zone(zone)
    minutes = target.hour * 60 + target.min
    return target if minutes.between?(start_hour * 60 + start_minute, end_hour * 60 + end_minute)

    date = target.to_date
    date += 1 if minutes > end_hour * 60 + end_minute
    zone.local(date.year, date.month, date.day, start_hour, start_minute)
  end

  def parse_time(value)
    Time.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
