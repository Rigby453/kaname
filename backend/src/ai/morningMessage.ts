/**
 * AI-02: Утреннее сообщение (tone-aware).
 * Генерирует 1-2 предложения под тон gentle/harsh через провайдер (Gemini/Claude).
 * Вызов модели — только через provider.ts.
 *
 * Issue #18: обёрнут withAiRetry — раньше этот вызов не ретраился вовсе.
 */

import { generateText } from "./provider.js";
import { unwrapMaybeJson } from "./textResponse.js";
import { withAiRetry } from "./retry.js";
import { languageDirective } from "./langDirective.js";

export type Tone = "gentle" | "harsh";

/**
 * Возвращает короткое утреннее сообщение.
 * @param pendingCount - сколько незавершённых задач перенесено на сегодня
 * @param tone - gentle (мягкий) / harsh (жёсткий)
 * @param userName - имя пользователя (опционально)
 * @param language - язык сообщения (напр. "Russian"), по умолчанию "English"
 * @param languageCode - ISO-код языка (напр. "ru"), опционально — усиливает
 *   языковую инструкцию (модели лучше держат код рядом с названием)
 */
export async function generateMorningMessage(params: {
  pendingCount: number;
  tone: Tone;
  userName?: string;
  language?: string;
  languageCode?: string;
}): Promise<{ message: string }> {
  const { pendingCount, tone, userName, language = "English", languageCode } = params;

  const toneHint =
    tone === "harsh"
      ? "Be blunt, no-nonsense and a little provocative, but never insulting."
      : "Be warm, purposeful and forward-looking.";

  // Жёсткая языковая инструкция дублируется в начале (primacy) И в конце
  // (recency) промпта — дешёвые dev-модели (Groq llama-3.1-8b-instant) хуже
  // держат единственную инструкцию, зарытую в конце длинного system-промпта.
  const langLine = languageDirective(language, languageCode);

  // Запрещаем пустые ободрялки; требуем конкретный фокус-акцент на начало дня.
  const system =
    `${langLine}\n\n` +
    "You write the morning nudge for a student planner. " +
    "Output ONE or TWO short sentences, plain text, no emoji, no quotes. " +
    "DO NOT use empty phrases like 'you can do it', 'have a great day', or 'don't worry'. " +
    "DO NOT repeat the number of tasks back to the user — they already see it. " +
    "Instead give ONE concrete approach or focus tip that fits the workload: " +
    "e.g. tackle the hardest task first, batch quick tasks before 10am, protect a focused block, etc. " +
    "Be specific and action-oriented. " +
    toneHint +
    `\n\nIMPORTANT: ${langLine}`;

  const who = userName ? `The user's name is ${userName}. ` : "";
  const taskSituation =
    pendingCount === 0
      ? "No tasks carried over — today is a clean slate."
      : `${pendingCount} task(s) carried over from yesterday.`;

  const user =
    `${who}${taskSituation} ` +
    "Write a short morning nudge with one concrete focus tip. Do not mention the count.";

  // withAiRetry повторяет вызов при временных сбоях (rate-limit/перегрузка);
  // постоянные сбои (гео-блок, суточная квота, пустой ответ) идут наверх сразу.
  const message = await withAiRetry(() => callAndUnwrap({ system, user }));
  return { message };
}

async function callAndUnwrap(args: { system: string; user: string }): Promise<string> {
  const raw = await generateText({
    system: args.system,
    user: args.user,
    maxTokens: 180,
    tier: "fast",
  });
  // Защита: если модель всё же вернула JSON {"message":"..."} — разворачиваем в текст.
  const message = unwrapMaybeJson(raw, "message");
  if (!message) throw new Error("AI returned an empty morning message.");
  return message;
}
