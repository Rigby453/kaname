import type { Item } from "@prisma/client";

// Тип ответа для Item — строго по api-spec.yaml (snake_case)
export interface SerializedItem {
  id: string;
  user_id: string;
  title: string;
  type: string;
  priority: string;
  status: string;
  scheduled_at: string;
  duration_minutes: number;
  is_protected: boolean;
  recurrence_rule: string | null;
  created_at: string;
  updated_at: string;
}

/**
 * Преобразует Prisma Item (camelCase) в snake_case ответ API.
 * Явный маппинг каждого поля — гарантирует соответствие api-spec.yaml.
 */
export function serializeItem(item: Item): SerializedItem {
  return {
    id: item.id,
    user_id: item.userId,
    title: item.title,
    type: item.type,
    priority: item.priority,
    status: item.status,
    scheduled_at: item.scheduledAt.toISOString(),
    duration_minutes: item.durationMinutes,
    is_protected: item.isProtected,
    recurrence_rule: item.recurrenceRule ?? null,
    created_at: item.createdAt.toISOString(),
    updated_at: item.updatedAt.toISOString(),
  };
}
