// Conventional Commits, enforced locally (husky commit-msg hook) and in CI (PR title + PR commits).
// Scope = addon folder name (e.g. `feat(OrdaenMinimap): ...`) or one of the repo-level scopes.
// Note: release-please assigns a commit to an addon by the files it touches, not by its scope.
import { readdirSync } from 'node:fs';

const addons = readdirSync(new URL('./addons/', import.meta.url), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name);

const repoScopes = ['repo', 'ci', 'deps', 'scripts', 'tests', 'docs', 'main', 'art', 'api'];

export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [2, 'always', [...addons, ...repoScopes]],
    // Addon names are PascalCase.
    'scope-case': [0],
    // Subjects may start with a capital: code names like `UI.DressBar` or `Blizzard_*`.
    'subject-case': [0],
    // A long subject is a warning, not an error: keep them short, but a precise one may run long.
    'header-max-length': [1, 'always', 100],
    // Bot-written bodies (release-please, dependabot) contain long URLs.
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
  },
};
