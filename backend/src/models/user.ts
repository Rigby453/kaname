import type { User } from "@prisma/client";

// Тип ответа для пользователя — строго по api-spec.yaml (snake_case, без passwordHash).
// email и phone теперь nullable (406-ФЗ).
export interface SerializedUser {
  id: string;
  email: string | null;
  phone: string | null;
  name: string;
  subscription_tier: string;
  theme: string;
  tone_preference: string;
  created_at: string;
  updated_at: string;
}

/**
 * Преобразует Prisma User (camelCase) в snake_case ответ API.
 * Гарантирует отсутствие passwordHash в ответе.
 * email и phone могут быть null (пользователь зарегистрирован по телефону или email).
 */
export function serializeUser(user: User): SerializedUser {
  return {
    id: user.id,
    email: user.email ?? null,
    phone: user.phone ?? null,
    name: user.name,
    subscription_tier: user.subscriptionTier,
    theme: user.theme,
    tone_preference: user.tonePreference,
    created_at: user.createdAt.toISOString(),
    updated_at: user.updatedAt.toISOString(),
  };
}
