import type {
  FastifyInstance,
  FastifyPluginAsync,
  FastifyReply,
  FastifyRequest,
} from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { serializeItem } from "../models/item.js";
import { requireAuth } from "./middleware/auth.js";

// Payload, закодированный в JWT для ссылок-шаров
interface SharePayload {
  purpose: "share";
  user_id: string;
  from: string;
  to: string;
}

// Функция экранирования HTML для защиты от инъекций в пользовательских текстах
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// Форматирует дату/время в HH:MM (UTC)
function formatTime(date: Date): string {
  const hh = String(date.getUTCHours()).padStart(2, "0");
  const mm = String(date.getUTCMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
}

// Форматирует дату в читаемый вид YYYY-MM-DD
function formatDate(iso: string): string {
  return iso.slice(0, 10);
}

// Zod-схема для входящего запроса POST /api/v1/share
const createShareSchema = z.object({
  from: z.string().datetime({ offset: true }),
  to: z.string().datetime({ offset: true }),
});

// Тип одного item для публичного ответа (БЕЗ id, БЕЗ user_id и приватных полей)
interface PublicItem {
  title: string;
  type: string;
  scheduled_at: string;
  duration_minutes: number;
  status: string;
}

// Общий хелпер: извлекает данные по токену, возвращает объект для JSON или HTML.
// fastify.jwt.verify синхронный (бросает на invalid/expired); аугментация
// FastifyJWT типизирует payload под auth-токен, поэтому приводим через unknown.
async function resolveShare(
  fastify: FastifyInstance,
  token: string
): Promise<
  | { ok: false; reason: string }
  | { ok: true; ownerName: string; from: string; to: string; items: PublicItem[] }
> {
  let payload: SharePayload;
  try {
    const raw = fastify.jwt.verify(token) as unknown;
    // Проверяем, что это именно share-токен
    if (
      !raw ||
      typeof raw !== "object" ||
      (raw as Record<string, unknown>)["purpose"] !== "share"
    ) {
      return { ok: false, reason: "Link expired or invalid" };
    }
    payload = raw as SharePayload;
  } catch {
    return { ok: false, reason: "Link expired or invalid" };
  }

  // Загружаем пользователя
  const user = await prisma.user.findUnique({ where: { id: payload.user_id } });
  if (!user) {
    return { ok: false, reason: "Link expired or invalid" };
  }

  // Загружаем items в диапазоне [from, to)
  const items = await prisma.item.findMany({
    where: {
      userId: payload.user_id,
      scheduledAt: {
        gte: new Date(payload.from),
        lt: new Date(payload.to),
      },
    },
    orderBy: { scheduledAt: "asc" },
  });

  const serialized = items.map(serializeItem);

  const publicItems: PublicItem[] = serialized.map((item) => ({
    title: item.title,
    type: item.type,
    scheduled_at: item.scheduled_at,
    duration_minutes: item.duration_minutes,
    status: item.status,
  }));

  return {
    ok: true,
    ownerName: user.name,
    from: payload.from,
    to: payload.to,
    items: publicItems,
  };
}

// Строит минималистичную HTML-страницу в стиле тёмной темы Focus
function buildHtmlPage(
  ownerName: string,
  from: string,
  to: string,
  items: PublicItem[]
): string {
  // Группируем items по дате
  const byDay = new Map<string, PublicItem[]>();
  for (const item of items) {
    const day = item.scheduled_at.slice(0, 10);
    if (!byDay.has(day)) byDay.set(day, []);
    byDay.get(day)!.push(item);
  }

  const daysHtml = Array.from(byDay.entries())
    .map(([day, dayItems]) => {
      const dayLabel = escapeHtml(day);
      const rowsHtml = dayItems
        .map((it) => {
          const time = formatTime(new Date(it.scheduled_at));
          const title = escapeHtml(it.title);
          const type = escapeHtml(it.type);
          const statusClass =
            it.status === "done"
              ? "done"
              : it.status === "skipped"
              ? "skipped"
              : "pending";
          return `
      <div class="item">
        <span class="time">${time}</span>
        <span class="title">${title}</span>
        <span class="badge badge-type">${type}</span>
        <span class="badge badge-status ${statusClass}">${escapeHtml(it.status)}</span>
      </div>`;
        })
        .join("");

      return `
    <div class="day-block">
      <h3 class="day-label">${dayLabel}</h3>
      ${rowsHtml}
    </div>`;
    })
    .join("");

  const rangeLabel = `${formatDate(from)} — ${formatDate(to)}`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(ownerName)}'s plan · Kaizen</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: #141009;
      color: #F6EFE1;
      font-family: system-ui, -apple-system, sans-serif;
      min-height: 100vh;
      padding: 32px 16px 64px;
    }
    .container { max-width: 640px; margin: 0 auto; }
    h1 { font-size: 1.6rem; font-weight: 700; color: #D9F24B; margin-bottom: 4px; }
    .range { font-size: 0.85rem; color: #9e9787; margin-bottom: 32px; }
    .day-block { margin-bottom: 28px; }
    .day-label { font-size: 0.95rem; font-weight: 600; color: #D9F24B; margin-bottom: 10px; letter-spacing: 0.04em; text-transform: uppercase; }
    .item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 0;
      border-bottom: 1px solid #2a2519;
      flex-wrap: wrap;
    }
    .time { font-size: 0.85rem; color: #9e9787; min-width: 40px; font-variant-numeric: tabular-nums; }
    .title { flex: 1; font-size: 1rem; }
    .badge {
      font-size: 0.72rem;
      padding: 2px 8px;
      border-radius: 99px;
      font-weight: 600;
      letter-spacing: 0.03em;
      text-transform: uppercase;
    }
    .badge-type { background: #2a2519; color: #D9F24B; }
    .badge-status.done { background: #1e3a1a; color: #6ee77a; }
    .badge-status.skipped { background: #3a2a1a; color: #e7a96e; }
    .badge-status.pending { background: #2a2519; color: #9e9787; }
    .footer {
      margin-top: 48px;
      font-size: 0.78rem;
      color: #5a5345;
      text-align: center;
    }
    .footer span { color: #D9F24B; }
  </style>
</head>
<body>
  <div class="container">
    <h1>${escapeHtml(ownerName)}'s plan</h1>
    <p class="range">${escapeHtml(rangeLabel)}</p>
    ${daysHtml || '<p style="color:#9e9787">No items in this range.</p>'}
    <div class="footer">Shared from <span>Kaizen</span> — the important stuff won't slip</div>
  </div>
</body>
</html>`;
}

const shareRoutes: FastifyPluginAsync = async (fastify) => {
  // SHARE-01: POST /api/v1/share — создать ссылку-шар (требует авторизации)
  fastify.post(
    "/api/v1/share",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = createShareSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      const { from, to } = parsed.data;
      const userId = request.user.userId;

      const fromDate = new Date(from);
      const toDate = new Date(to);

      // to должна быть строго позже from
      if (toDate <= fromDate) {
        return reply.status(400).send({ error: "'to' must be after 'from'" });
      }

      // Максимальный диапазон — 31 день
      const diffMs = toDate.getTime() - fromDate.getTime();
      const diffDays = diffMs / (1000 * 60 * 60 * 24);
      if (diffDays > 31) {
        return reply.status(400).send({ error: "Range must not exceed 31 days" });
      }

      // Подписываем JWT с purpose=share.
      // Payload намеренно шире, чем тип аутентификационного JWT { userId, email } —
      // используем приведение типа, чтобы обойти глобальное ограничение FastifyJWT.
      const sharePayload: SharePayload = {
        purpose: "share",
        user_id: userId,
        from,
        to,
      };
      const token = await fastify.jwt.sign(
        sharePayload as unknown as Parameters<typeof fastify.jwt.sign>[0],
        { expiresIn: "7d" }
      );

      const baseUrl =
        process.env["PUBLIC_BASE_URL"] ?? "http://localhost:3000";
      const url = `${baseUrl}/share/${token}`;

      return reply.status(200).send({ token, url });
    }
  );

  // Общий хендлер ответа для обоих GET-маршрутов (публичные, без авторизации)
  async function handleShareGet(
    request: FastifyRequest<{ Params: { token: string } }>,
    reply: FastifyReply
  ): Promise<FastifyReply> {
    const { token } = request.params;
    const acceptHeader = request.headers.accept ?? "";
    const wantsHtml = acceptHeader.includes("text/html");

    const result = await resolveShare(fastify, token);
    if (!result.ok) {
      // Если клиент принимает HTML — отдаём HTML-ошибку, иначе JSON 404
      if (wantsHtml) {
        return reply
          .status(404)
          .type("text/html")
          .send(
            `<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Link expired</title></head><body style="background:#141009;color:#F6EFE1;font-family:system-ui;padding:40px;text-align:center"><h1 style="color:#D9F24B">Link expired or invalid</h1><p>This share link is no longer valid.</p></body></html>`
          );
      }
      return reply.status(404).send({ error: "Link expired or invalid" });
    }

    if (wantsHtml) {
      const html = buildHtmlPage(
        result.ownerName,
        result.from,
        result.to,
        result.items
      );
      return reply.type("text/html").send(html);
    }

    // JSON-ответ (для приложения)
    return reply.status(200).send({
      owner_name: result.ownerName,
      from: result.from,
      to: result.to,
      items: result.items,
    });
  }

  // SHARE-02: GET /share/:token — публичная страница (без авторизации)
  fastify.get<{ Params: { token: string } }>(
    "/share/:token",
    (request, reply) => handleShareGet(request, reply)
  );

  // SHARE-03: GET /api/v1/share/:token — тот же JSON для приложения (без авторизации)
  fastify.get<{ Params: { token: string } }>(
    "/api/v1/share/:token",
    (request, reply) => handleShareGet(request, reply)
  );
};

export default shareRoutes;
