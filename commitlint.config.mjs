export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', ['feat', 'fix', 'perf', 'deps', 'docs', 'test', 'refactor', 'build', 'ci', 'chore', 'revert']],
    'subject-case': [2, 'never', ['sentence-case', 'start-case', 'pascal-case', 'upper-case']],
    'header-max-length': [2, 'always', 100],
    'signed-off-by': [2, 'always', 'Signed-off-by:'],
  },
};
