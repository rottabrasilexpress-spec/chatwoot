import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const followUpSource = readFileSync(
  resolve(
    process.cwd(),
    'app/javascript/dashboard/routes/dashboard/settings/labels/FollowUp.vue'
  ),
  'utf8'
);

describe('follow-up responsive board', () => {
  it('keeps every trail column readable on desktop and mobile', () => {
    expect(followUpSource).toMatch(
      /\.rotta-board--trails\s*\{[^}]*grid-auto-columns:\s*minmax\(16rem,\s*18rem\)/s
    );
    expect(followUpSource).toMatch(
      /@media \(max-width:\s*640px\)[\s\S]*?\.rotta-board--trails\s*\{[^}]*grid-template-columns:\s*none;[^}]*grid-auto-columns:\s*min\(21rem,\s*calc\(100vw - 3\.75rem\)\)/s
    );
  });

  it('shows actionable error and commercial-window feedback in every layout', () => {
    expect(
      followUpSource.match(/v-if="followUpFeedback\(job\)"/g)
    ).toHaveLength(3);
    expect(followUpSource).toContain('Aguardando horário comercial');
    expect(followUpSource).toContain('job?.last_error');
    expect(followUpSource).toContain('job?.error_message');
    expect(followUpSource).toMatch(
      /\.rotta-follow-up-feedback strong,[\s\S]*?overflow-wrap:\s*anywhere/
    );
    expect(followUpSource).toMatch(
      /@media \(max-width:\s*640px\)[\s\S]*?\.rotta-follow-up-feedback\s*\{[^}]*font-size:\s*0\.75rem/s
    );
  });

  it('provides a responsive failure summary with exact worker errors', () => {
    expect(followUpSource).toContain('Falhas de follow-up');
    expect(followUpSource).toContain('exactFailureText(job)');
    expect(followUpSource).toContain('O fluxo não informou o erro exato.');
    expect(followUpSource).toMatch(
      /\.rotta-summary-grid\s*\{[^}]*grid-template-columns:\s*repeat\(4,/s
    );
    expect(followUpSource).toMatch(
      /@media \(max-width:\s*640px\)[\s\S]*?\.rotta-failure-row\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)/s
    );
    expect(followUpSource).toMatch(
      /\.rotta-failure-row__reason p\s*\{[^}]*overflow-wrap:\s*anywhere/s
    );
  });
});
