import type { DayLog } from "@prisma/client";

// Тип ответа для DayLog — snake_case по api-spec.yaml
export interface SerializedDayLog {
  id: string;
  user_id: string;
  date: string; // YYYY-MM-DD
  mood: number | null;
  note: string | null;
  insight: string | null;
  created_at: string;
  updated_at: string;
}

export function serializeDayLog(log: DayLog): SerializedDayLog {
  return {
    id: log.id,
    user_id: log.userId,
    date: log.date.toISOString().slice(0, 10),
    mood: log.mood,
    note: log.note,
    insight: log.insight,
    created_at: log.createdAt.toISOString(),
    updated_at: log.updatedAt.toISOString(),
  };
}
