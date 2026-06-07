/**
 * AI-06: Импорт расписания из фото
 * Вызывает Claude (claude-haiku-4-5) для распознавания расписания с изображения.
 * Единственное место в проекте, где производится multimodal-вызов Claude для этой задачи.
 */

import Anthropic from '@anthropic-ai/sdk';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { z } from 'zod';

// ---------------------------------------------------------------------------
// Публичные типы (экспортируются для маршрута)
// ---------------------------------------------------------------------------

export interface ScheduleImportItem {
  title: string;
  /** ISO 8601, UTC — например "2025-09-01T09:00:00.000Z" */
  scheduledAt: string;
}

export interface ScheduleImportResult {
  items: ScheduleImportItem[];
}

// ---------------------------------------------------------------------------
// Zod-схема для ответа модели
// ---------------------------------------------------------------------------

/** Одна запись, которую Claude извлекает из изображения */
const RawEntrySchema = z.object({
  title: z.string().min(1),
  /** 24-часовой формат "HH:MM" */
  time: z.string().regex(/^\d{2}:\d{2}$/, 'Expected HH:MM (24-hour format)'),
});

/** Массив записей — то, что Claude должен вернуть */
const RawScheduleSchema = z.array(RawEntrySchema);

// ---------------------------------------------------------------------------
// Ленивая инициализация клиента
// ---------------------------------------------------------------------------

let _client: Anthropic | null = null;

function getClient(): Anthropic {
  if (_client) return _client;

  const apiKey = process.env['ANTHROPIC_API_KEY'];
  if (!apiKey) {
    throw new Error(
      'ANTHROPIC_API_KEY is not set. Add it to backend/.env before calling importScheduleFromPhoto.',
    );
  }

  _client = new Anthropic({ apiKey });
  return _client;
}

// ---------------------------------------------------------------------------
// Основная функция
// ---------------------------------------------------------------------------

/**
 * Отправляет изображение расписания в Claude и возвращает список занятий.
 *
 * @param params.imageBase64  - base64-строка (без data URI prefix)
 * @param params.mediaType    - MIME-тип изображения
 * @param params.targetDate   - дата в формате 'YYYY-MM-DD', используется для построения ISO-меток
 */
export async function importScheduleFromPhoto(params: {
  imageBase64: string;
  mediaType: 'image/jpeg' | 'image/png';
  targetDate: string;
}): Promise<ScheduleImportResult> {
  const { imageBase64, mediaType, targetDate } = params;

  // Проверяем формат даты до вызова API
  if (!/^\d{4}-\d{2}-\d{2}$/.test(targetDate)) {
    throw new Error(`targetDate must be in YYYY-MM-DD format, got: "${targetDate}"`);
  }

  const client = getClient();

  // Системная инструкция помечена как ephemeral для prompt caching:
  // при повторных вызовах с тем же system-блоком Anthropic кэширует токены → экономия.
  const systemPrompt =
    'You are a timetable extraction assistant. ' +
    'Read the schedule or timetable shown in the image. ' +
    'Return ONLY a JSON array — no prose, no markdown fences, no extra keys. ' +
    'Each element must be an object with exactly two fields: ' +
    '"title" (string, the class or event name) and ' +
    '"time" (string, 24-hour format "HH:MM"). ' +
    'If a time cannot be determined for an entry, omit that entry entirely. ' +
    'If the image contains no schedule, return an empty array [].';

  const userTextInstruction =
    'Extract all schedule items from this timetable image. ' +
    'Return a JSON array of { "title": string, "time": "HH:MM" } objects only.';

  // messages.parse() отправляет output_config → модель возвращает JSON,
  // SDK автоматически валидирует ответ через zodOutputFormat
  const message = await client.messages.parse({
    model: 'claude-haiku-4-5',
    max_tokens: 500,
    system: [
      {
        type: 'text',
        text: systemPrompt,
        // Prompt caching: статичный system-блок будет кэшироваться Anthropic API
        cache_control: { type: 'ephemeral' },
      },
    ],
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            source: {
              type: 'base64',
              media_type: mediaType,
              data: imageBase64,
            },
          },
          {
            type: 'text',
            text: userTextInstruction,
          },
        ],
      },
    ],
    output_config: {
      format: zodOutputFormat(RawScheduleSchema),
    },
  });

  // parsed_output содержит уже провалидированный массив (или null при сбое парсинга)
  const rawEntries = message.parsed_output;

  if (!Array.isArray(rawEntries)) {
    // Защитная ветка: parsed_output оказался null (модель вернула некорректный JSON)
    throw new Error(
      'Claude returned an unparseable response for schedule import. ' +
        `Stop-reason: ${message.stop_reason ?? 'unknown'}.`,
    );
  }

  // Строим ScheduleImportItem[], комбинируя targetDate + HH:MM из ответа модели.
  // Дата-арифметика выполняется в коде (детерминировано) — модель отвечает только за извлечение.
  const items: ScheduleImportItem[] = [];

  for (const entry of rawEntries) {
    // Разбиваем "HH:MM" — Zod-схема уже гарантирует формат, но проверяем диапазоны
    const [hhStr, mmStr] = entry.time.split(':');
    const hh = parseInt(hhStr ?? '', 10);
    const mm = parseInt(mmStr ?? '', 10);

    if (
      isNaN(hh) || isNaN(mm) ||
      hh < 0 || hh > 23 ||
      mm < 0 || mm > 59
    ) {
      // Пропускаем запись с невалидным временем
      continue;
    }

    const scheduledAt = `${targetDate}T${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00.000Z`;

    items.push({
      title: entry.title,
      scheduledAt,
    });
  }

  return { items };
}
