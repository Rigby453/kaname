module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  // rootDir = backend/ (where node_modules + ts-jest live, so the preset resolves)
  rootDir: '.',
  roots: ['<rootDir>/../tests'],
  testMatch: ['<rootDir>/../tests/**/*.test.ts'],
  setupFiles: ['<rootDir>/jest.setup.ts'],
  // Node16 source uses .js specifiers — strip them so ts-jest resolves the .ts sources
  moduleNameMapper: { '^(\\.{1,2}/.*)\\.js$': '$1' },
  // isolatedModules: транспиляция без полного типчека — устраняет кросс-файловые
  // ошибки разрешения (.js-спецификаторы Node16) и ускоряет прогон.
  transform: { '^.+\\.ts$': ['ts-jest', { isolatedModules: true, tsconfig: { module: 'commonjs', esModuleInterop: true } }] },
  collectCoverageFrom: ['<rootDir>/src/engine/**/*.ts'],
  testTimeout: 30000,
};
