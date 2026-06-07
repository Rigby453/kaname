import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { requireAuth } from "./middleware/auth.js";
import { importScheduleFromPhoto } from "../ai/scheduleImport.js";

// Zod-схема тела запроса (api-spec.yaml: /api/v1/ai/schedule-import)
const scheduleImportSchema = z.object({
  image_base64: z.string().min(1),
  media_type: z.enum(["image/jpeg", "image/png"]),
  target_date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, "target_date must be YYYY-MM-DD"),
});

const aiRoutes: FastifyPluginAsync = async (fastify) => {
  // AI-06: POST /api/v1/ai/schedule-import — фото расписания → задачи (premium, Phase 1)
  // Claude вызывается ТОЛЬКО через src/ai/. Ничего не сохраняется — клиент подтверждает и создаёт items.
  fastify.post(
    "/api/v1/ai/schedule-import",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = scheduleImportSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      // Premium-гейт: AI — платная фича. Free-тариф → 403.
      const user = await prisma.user.findUnique({
        where: { id: request.user.userId },
        select: { subscriptionTier: true },
      });
      if (!user) {
        return reply.status(404).send({ error: "Not found" });
      }
      if (user.subscriptionTier !== "premium") {
        return reply
          .status(403)
          .send({ error: "Premium feature — upgrade to use AI photo import" });
      }

      const { image_base64, media_type, target_date } = parsed.data;

      try {
        const result = await importScheduleFromPhoto({
          imageBase64: image_base64,
          mediaType: media_type,
          targetDate: target_date,
        });
        // Ответ в snake_case по контракту
        return reply.status(200).send({
          items: result.items.map((i) => ({
            title: i.title,
            scheduled_at: i.scheduledAt,
          })),
        });
      } catch (err) {
        fastify.log.error({ err }, "schedule-import AI call failed");
        // Ошибка апстрима (нет ключа / сбой Claude / неразбираемый ответ)
        return reply
          .status(502)
          .send({ error: "AI service unavailable. Please try again later." });
      }
    }
  );
};

export default aiRoutes;
