import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import prisma from "../models/prisma.js";
import { serializeUser } from "../models/user.js";
import { requireAuth } from "./middleware/auth.js";

// DEV-переключение тарифа без реальной оплаты. Реальные платежи (RevenueCat)
// — Phase 1. Эндпоинт нужен, чтобы тестировать premium-фичи (AI) до интеграции
// платежей. В production он недоступен (404).
const devUpgradeSchema = z.object({
  tier: z.enum(["free", "premium"]).default("premium"),
});

const subscriptionRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.post(
    "/api/v1/subscription/dev-upgrade",
    { preHandler: requireAuth },
    async (request, reply) => {
      // Жёсткий гейт: только вне production.
      if (process.env["NODE_ENV"] === "production") {
        return reply.status(404).send({ error: "Not found" });
      }

      const parsed = devUpgradeSchema.safeParse(request.body ?? {});
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.issues[0]?.message ?? "Validation error",
        });
      }

      const updated = await prisma.user.update({
        where: { id: request.user.userId },
        data: { subscriptionTier: parsed.data.tier },
      });

      return reply.status(200).send(serializeUser(updated));
    }
  );
};

export default subscriptionRoutes;
