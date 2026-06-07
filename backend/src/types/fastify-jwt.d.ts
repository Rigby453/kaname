// Augmentation модуля @fastify/jwt — типизируем payload и user без `any`
declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: { userId: string; email: string };
    user: { userId: string; email: string };
  }
}

export {};
