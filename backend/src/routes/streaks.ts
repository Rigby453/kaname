import type { FastifyPluginAsync } from "fastify";
import prisma from "../models/prisma.js";
import { serializeStreak } from "../models/streak.js";
import { requireAuth } from "./middleware/auth.js";

const streaksRoutes: FastifyPluginAsync = async (fastify) => {
  // STREAK-01: GET /api/v1/streaks — получить серию текущего пользователя
  // Если streak не существует — создаём с дефолтами (current=0, longest=0)
  fastify.get(
    "/api/v1/streaks",
    { preHandler: requireAuth },
    async (request, reply) => {
      const userId = request.user.userId;

      // upsert: если нет — создаём с дефолтами
      const streak = await prisma.streak.upsert({
        where: { userId },
        create: {
          userId,
          current: 0,
          longest: 0,
          freezeCount: 0,
        },
        update: {}, // ничего не меняем если уже есть
      });

      return reply.status(200).send(serializeStreak(streak));
    }
  );
};

export default streaksRoutes;
