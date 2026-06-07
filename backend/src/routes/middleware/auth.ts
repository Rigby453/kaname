import type { FastifyRequest, FastifyReply } from "fastify";

/**
 * preHandler для защищённых маршрутов.
 * Верифицирует Bearer JWT и прикрепляет req.user = { userId, email }.
 * При ошибке возвращает 401 { error: "Unauthorized" }.
 */
export async function requireAuth(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    await request.jwtVerify();
  } catch {
    await reply.status(401).send({ error: "Unauthorized" });
  }
}
