/// Compile-time gate for store-only features (rate-app, native review).
/// Flip at publication via --dart-define=APP_PUBLISHED=true.
const bool kAppPublished = bool.fromEnvironment('APP_PUBLISHED', defaultValue: false);
