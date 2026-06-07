import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { requireAuth } from "./middleware/auth.js";
import { proposeRedistribution } from "../engine/redistributor.js";
import { serializeItem } from "../models/item.js";

// Zod-схема тела запроса: { target_date: "YYYY-MM-DD" }
const redistributeBodySchema = z.object({
  target_date: z
    .string()
    .regex(
      /^\d{4}-\d{2}-\d{2}$/,
      "target_date must be a date in format YYYY-MM-DD"
    ),
});

const redistributeRoutes: FastifyPluginAsync = async (fastify) => {
  // ENGINE-01: POST /api/v1/redistribute — предлагает перераспределение задач
  // Ничего не сохраняет в БД — возвращает только proposal.
  // Клиент применяет выбранный план через PATCH /api/v1/items/:id.
  fastify.post(
    "/api/v1/redistribute",
    { preHandler: requireAuth },
    async (request, reply) => {
      // Валидация тела запроса
      const parsed = redistributeBodySchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      const { target_date } = parsed.data;
      const userId = request.user.userId;

      // Парсим дату в Date-объект (интерпретируем как UTC-полночь)
      const targetDate = new Date(`${target_date}T00:00:00.000Z`);

      // Проверяем, что дата валидна (e.g. не "2024-13-99")
      if (isNaN(targetDate.getTime())) {
        return reply.status(400).send({ error: "Invalid target_date value" });
      }

      // Запускаем rule-based engine — без AI, без сохранения в БД
      const { proposed, skipped } = await proposeRedistribution(
        userId,
        targetDate
      );

      // Ответ точно по RedistributeResponse из api-spec.yaml
      return reply.status(200).send({
        proposed: proposed.map(serializeItem),
        skipped: skipped.map(serializeItem),
      });
    }
  );
};

export default redistributeRoutes;
