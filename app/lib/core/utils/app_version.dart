// Compile-time идентификатор сборки, передаётся через
// --dart-define=APP_BUILD_TAG=<значение> (например git-хэш или CI-тег).
// Если не задан — пустая строка; виджет просто скрывает тег-часть.
const String kAppBuildTag =
    String.fromEnvironment('APP_BUILD_TAG', defaultValue: '');
