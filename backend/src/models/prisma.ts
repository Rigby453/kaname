import { PrismaClient } from "@prisma/client";

// Singleton Prisma клиент — предотвращаем создание множества соединений
const prisma = new PrismaClient();

export default prisma;
