import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const followUpSource = readFileSync(
  fileURLToPath(new URL('../FollowUp.vue', import.meta.url)),
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
});
