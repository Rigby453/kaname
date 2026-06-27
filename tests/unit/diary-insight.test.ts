/**
 * Unit tests for generateDiaryInsight (AI-04).
 * Provider полностью мокируется — реальных API-вызовов нет.
 * Проверяем: исправление обрезания (maxTokens ≥ 600), диапазон дат, unwrap JSON.
 */

import { generateDiaryInsight } from "../../backend/src/ai/diaryInsight";
import * as provider from "../../backend/src/ai/provider";

// Мокируем провайдер (ADR-022): никаких реальных вызовов Gemini/Claude в тестах.
jest.mock("../../backend/src/ai/provider", () => ({
  generateText: jest.fn(),
}));

const mockGenerate = provider.generateText as jest.MockedFunction<
  typeof provider.generateText
>;

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/** 7 записей дневника, отсортированных по убыванию (как отдаёт маршрут). */
const LOGS = [
  { date: "2026-06-27", mood: 4, note: "Good progress" },
  { date: "2026-06-26", mood: 3, note: "Managed to finish key task" },
  { date: "2026-06-25", mood: 2, note: "Overwhelmed with deadlines" },
  { date: "2026-06-24", mood: 4, note: "Better today" },
  { date: "2026-06-23", mood: 3, note: null },
  { date: "2026-06-22", mood: 2, note: "Tired, procrastinated" },
  { date: "2026-06-21", mood: 4, note: "Good study session" },
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

beforeEach(() => {
  jest.clearAllMocks();
});

test("returns insight from plain text response", async () => {
  const expected =
    "Your mood consistently dips mid-week when deadlines pile up. " +
    "Try scheduling your hardest task Monday morning to reduce Wednesday anxiety.";
  mockGenerate.mockResolvedValueOnce(expected);

  const result = await generateDiaryInsight({ logs: LOGS, tone: "gentle" });
  expect(result.insight).toBe(expected);
});

test("unwraps JSON-wrapped insight (model sometimes returns {\"insight\":\"...\"})", async () => {
  const raw = '{"insight": "You journal most on Sundays and mood is higher then."}';
  mockGenerate.mockResolvedValueOnce(raw);

  const result = await generateDiaryInsight({ logs: LOGS, tone: "gentle" });
  expect(result.insight).toBe("You journal most on Sundays and mood is higher then.");
});

test("throws on empty response (guarded against empty string from model)", async () => {
  mockGenerate.mockResolvedValueOnce("");
  await expect(
    generateDiaryInsight({ logs: LOGS, tone: "gentle" })
  ).rejects.toThrow(/empty diary insight/i);
});

// ---------------------------------------------------------------------------
// Truncation fix: maxTokens raised from 450 → 650
// ---------------------------------------------------------------------------

test("uses maxTokens >= 600 to prevent mid-JSON truncation", async () => {
  // Корень проблемы: при 450 токенах Gemini 2.5-flash обрезал JSON {"insight":"...}
  // до закрытия кавычки. unwrapMaybeJson падал на parse → клиент видел сырой JSON.
  mockGenerate.mockResolvedValueOnce("Insight text.");
  await generateDiaryInsight({ logs: LOGS, tone: "gentle" });

  const callArg = mockGenerate.mock.calls[0]![0];
  expect(callArg.maxTokens).toBeGreaterThanOrEqual(600);
});

// ---------------------------------------------------------------------------
// Covered date range
// ---------------------------------------------------------------------------

test("returns coveredFrom/coveredTo computed from logs (min/max date)", async () => {
  mockGenerate.mockResolvedValueOnce("Insight here.");
  const result = await generateDiaryInsight({ logs: LOGS, tone: "gentle" });

  // Диапазон вычисляется кодом из входных дат, а не моделью.
  expect(result.coveredFrom).toBe("2026-06-21"); // самая ранняя
  expect(result.coveredTo).toBe("2026-06-27"); // самая поздняя
});

test("returns null covered range when no logs", async () => {
  mockGenerate.mockResolvedValueOnce("Start journaling to see your first insight.");
  const result = await generateDiaryInsight({ logs: [], tone: "gentle" });

  expect(result.coveredFrom).toBeNull();
  expect(result.coveredTo).toBeNull();
});

test("passes explicit date range to model user message", async () => {
  mockGenerate.mockResolvedValueOnce("Insight text.");
  await generateDiaryInsight({ logs: LOGS, tone: "gentle" });

  const { user } = mockGenerate.mock.calls[0]![0];
  // Явный диапазон в user-сообщении помогает модели ссылаться на него в инсайте.
  expect(user).toContain("2026-06-21");
  expect(user).toContain("2026-06-27");
});

// ---------------------------------------------------------------------------
// Tone handling
// ---------------------------------------------------------------------------

test("harsh tone produces blunt/direct hint in system prompt", async () => {
  mockGenerate.mockResolvedValueOnce("Direct insight here.");
  await generateDiaryInsight({ logs: LOGS, tone: "harsh" });

  const { system } = mockGenerate.mock.calls[0]![0];
  expect(system).toContain("blunt");
});

test("gentle tone produces warm/supportive hint in system prompt", async () => {
  mockGenerate.mockResolvedValueOnce("Warm insight here.");
  await generateDiaryInsight({ logs: LOGS, tone: "gentle" });

  const { system } = mockGenerate.mock.calls[0]![0];
  expect(system).toContain("warm");
});

// ---------------------------------------------------------------------------
// Language passthrough
// ---------------------------------------------------------------------------

test("passes language parameter into system prompt", async () => {
  mockGenerate.mockResolvedValueOnce("Инсайт на русском.");
  await generateDiaryInsight({ logs: LOGS, tone: "gentle", language: "Russian" });

  const { system } = mockGenerate.mock.calls[0]![0];
  expect(system).toContain("Russian");
});

// ---------------------------------------------------------------------------
// Prompt quality: insight requirement
// ---------------------------------------------------------------------------

test("system prompt forbids raw data restatement and demands non-obvious patterns", async () => {
  mockGenerate.mockResolvedValueOnce("A non-obvious pattern insight.");
  await generateDiaryInsight({ logs: LOGS, tone: "gentle" });

  const { system } = mockGenerate.mock.calls[0]![0];
  expect(system).toContain("NON-OBVIOUS");
  expect(system).toContain("DO NOT repeat");
  expect(system).toContain("Complete every sentence fully");
});
