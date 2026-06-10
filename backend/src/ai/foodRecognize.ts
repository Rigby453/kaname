/**
 * AI-03: распознавание еды по фото (Phase 1, premium).
 * Модель ТОЛЬКО называет блюдо ({dish, portion_description, confidence}) —
 * числа КБЖУ берутся из food DB (Open Food Facts), не из модели (правило ТЗ).
 * Вызов модели — только через provider.ts.
 */

import { z } from "zod";
import { generateText, stripJsonFences } from "./provider.js";

export interface FoodRecognition {
  dish: string;
  portionDescription: string;
  confidence: number;
}

const RecognitionSchema = z.object({
  dish: z.string().min(1),
  portion_description: z.string().default(""),
  confidence: z.number().min(0).max(1),
});

/** Отправляет фото еды в модель и возвращает название блюда + уверенность. */
export async function recognizeFood(params: {
  imageBase64: string;
  mediaType: "image/jpeg" | "image/png";
}): Promise<FoodRecognition> {
  const system =
    "Identify the food in this image. " +
    "Return ONLY JSON with exactly these fields: " +
    '{ "dish": string, "portion_description": string, "confidence": number }. ' +
    "dish must be a specific, searchable food name in English (e.g. " +
    '"grilled chicken breast", not "meat"). portion_description briefly ' +
    "describes the visible amount. confidence is 0..1. " +
    "If unclear, give your best guess with low confidence. " +
    "Do NOT estimate calories or nutrition — only identify the food.";

  const user = "What food is shown in this photo? JSON only.";

  const text = await generateText({
    system,
    user,
    maxTokens: 150,
    tier: "fast",
    json: true,
    image: { base64: params.imageBase64, mediaType: params.mediaType },
  });

  let parsed: unknown;
  try {
    parsed = JSON.parse(stripJsonFences(text));
  } catch {
    throw new Error("AI returned an unparseable response for food photo.");
  }
  const result = RecognitionSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error("AI returned an unexpected food-recognition shape.");
  }

  return {
    dish: result.data.dish,
    portionDescription: result.data.portion_description,
    confidence: result.data.confidence,
  };
}
