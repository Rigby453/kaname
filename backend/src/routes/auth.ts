import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import bcrypt from "bcrypt";
import prisma from "../models/prisma.js";
import { serializeUser } from "../models/user.js";
import { requireAuth } from "./middleware/auth.js";

// Zod-схемы для входных данных (api-spec.yaml: RegisterRequest, LoginRequest)
const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  name: z.string().min(1),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const authRoutes: FastifyPluginAsync = async (fastify) => {
  // AUTH-01: POST /api/v1/auth/register
  fastify.post("/api/v1/auth/register", async (request, reply) => {
    // Валидация входных данных
    const parsed = registerSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: parsed.error.issues[0]?.message ?? "Validation error",
      });
    }

    const { email, password, name } = parsed.data;

    // Проверяем уникальность email
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return reply.status(409).send({ error: "Email already exists" });
    }

    // Хешируем пароль
    const passwordHash = await bcrypt.hash(password, 12);

    // Создаём пользователя и Streak одной транзакцией
    const user = await prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: { email, passwordHash, name },
      });
      await tx.streak.create({
        data: {
          userId: newUser.id,
          current: 0,
          longest: 0,
          freezeCount: 0,
        },
      });
      return newUser;
    });

    // Подписываем JWT
    const accessToken = await reply.jwtSign(
      { userId: user.id, email: user.email },
      { expiresIn: "30d" }
    );

    return reply.status(201).send({
      access_token: accessToken,
      user: serializeUser(user),
    });
  });

  // AUTH-02: POST /api/v1/auth/login
  fastify.post("/api/v1/auth/login", async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: parsed.error.issues[0]?.message ?? "Validation error",
      });
    }

    const { email, password } = parsed.data;

    // Ищем пользователя
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return reply.status(401).send({ error: "Invalid credentials" });
    }

    // Сравниваем пароль
    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) {
      return reply.status(401).send({ error: "Invalid credentials" });
    }

    const accessToken = await reply.jwtSign(
      { userId: user.id, email: user.email },
      { expiresIn: "30d" }
    );

    return reply.status(200).send({
      access_token: accessToken,
      user: serializeUser(user),
    });
  });

  // AUTH-04: GET /api/v1/auth/me (защищённый маршрут)
  fastify.get(
    "/api/v1/auth/me",
    { preHandler: requireAuth },
    async (request, reply) => {
      const { userId } = request.user;

      const user = await prisma.user.findUnique({ where: { id: userId } });
      if (!user) {
        return reply.status(404).send({ error: "Not found" });
      }

      return reply.status(200).send(serializeUser(user));
    }
  );
};

export default authRoutes;
