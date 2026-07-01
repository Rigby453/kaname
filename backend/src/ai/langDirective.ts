/**
 * Общий хелпер для ЖЁСТКОЙ языковой инструкции во всех AI-промптах.
 *
 * Bug (device testing, 2026-07-01): RU-пользователь иногда получал ответ ИИ
 * на английском, хотя Accept-Language → language уже пробрасывался в промпт
 * (routes/ai.ts → langName()). Причина — инструкция была одной строкой в
 * конце длинного system-промпта ("Write all human-readable text in X."),
 * что дешёвые/маленькие dev-модели (Groq llama-3.1-8b-instant — приоритетный
 * dev-провайдер, см. provider.ts) иногда теряют или трактуют слабо.
 *
 * Фикс: единая, более настойчивая формулировка + код языка (модели лучше
 * держат ISO-код рядом с названием) + вызывающие функции ставят её ДВАЖДЫ —
 * в начале system-промпта (primacy) и в конце (recency). Централизовано
 * здесь, чтобы усиление формулировки не пришлось повторять по 6 файлам.
 */

/**
 * Инструкция для ПОЛНОСТЬЮ текстовых ответов (morning-message, diary-insight,
 * wrapped-summary) — весь ответ должен быть на языке пользователя.
 */
export function languageDirective(languageName: string, languageCode?: string): string {
  const codePart = languageCode ? ` (${languageCode})` : "";
  return (
    `Write your entire response in ${languageName}${codePart}. ` +
    "Do not use any other language, even English, regardless of the language of " +
    "these instructions or any examples above."
  );
}

/**
 * Инструкция для JSON-ответов, где только ЧАСТЬ полей — человекочитаемый
 * текст (остальное — ключи/ID/значения, которые должны остаться в английском
 * по формату контракта).
 * @param fields - описание полей, которые должны быть на языке пользователя
 *   (например: "the note field", "the label and reason fields")
 */
export function languageDirectiveForFields(
  fields: string,
  languageName: string,
  languageCode?: string
): string {
  const codePart = languageCode ? ` (${languageCode})` : "";
  return (
    `Write ${fields} in ${languageName}${codePart}. Do not use any other language, ` +
    "even English, for these fields, regardless of the language of these instructions. " +
    "Keep everything else (JSON keys, IDs, and any values the instructions above say " +
    "must stay in English) exactly as specified."
  );
}
