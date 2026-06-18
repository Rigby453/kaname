// Augmentation модуля @fastify/jwt — типизируем payload и user без `any`.
// email удалён из payload: после 406-ФЗ пользователь может быть зарегистрирован
// только по телефону, поэтому токен содержит только userId.
declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: { userId: string };
    user: { userId: string };
  }
}

export {};
