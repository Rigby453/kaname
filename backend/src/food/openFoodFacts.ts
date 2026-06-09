/**
 * Источник данных о продуктах — Open Food Facts (бесплатно, без ключа, открыто).
 * https://world.openfoodfacts.org . Числа КБЖУ берём отсюда (per 100 g), не из AI.
 * OFF просит указывать User-Agent.
 */

const OFF_BASE = "https://world.openfoodfacts.org";
const USER_AGENT = "Kaizen/1.0 (student planner; contact: support@kaizen.app)";

/** Нормализованный продукт (значения — на 100 г, null если неизвестно). */
export interface FoodProduct {
  code: string; // штрихкод / OFF id
  name: string;
  brand: string | null;
  per100g: {
    calories: number | null;
    protein: number | null;
    fat: number | null;
    carbs: number | null;
    sugar: number | null;
    fiber: number | null;
  };
}

// --- Сырые формы ответа OFF (только нужные поля) ---
interface OffNutriments {
  "energy-kcal_100g"?: number | string;
  proteins_100g?: number | string;
  fat_100g?: number | string;
  carbohydrates_100g?: number | string;
  sugars_100g?: number | string;
  fiber_100g?: number | string;
}
interface OffProduct {
  code?: string;
  product_name?: string;
  brands?: string;
  nutriments?: OffNutriments;
}
interface OffProductResponse {
  status?: number;
  product?: OffProduct;
}
interface OffSearchResponse {
  products?: OffProduct[];
}

function num(v: number | string | undefined): number | null {
  if (v === undefined || v === null || v === "") return null;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? Math.round(n * 10) / 10 : null;
}

function normalize(p: OffProduct, fallbackCode: string): FoodProduct | null {
  const name = (p.product_name ?? "").trim();
  if (!name) return null; // продукт без названия бесполезен
  const n = p.nutriments ?? {};
  return {
    code: (p.code ?? fallbackCode).trim(),
    name,
    brand: p.brands?.split(",")[0]?.trim() || null,
    per100g: {
      calories: num(n["energy-kcal_100g"]),
      protein: num(n.proteins_100g),
      fat: num(n.fat_100g),
      carbs: num(n.carbohydrates_100g),
      sugar: num(n.sugars_100g),
      fiber: num(n.fiber_100g),
    },
  };
}

const FIELDS = "code,product_name,brands,nutriments";

/** Поиск продукта по штрихкоду. null — не найден. */
export async function lookupBarcode(code: string): Promise<FoodProduct | null> {
  const res = await fetch(
    `${OFF_BASE}/api/v2/product/${encodeURIComponent(code)}.json?fields=${FIELDS}`,
    { headers: { "User-Agent": USER_AGENT } }
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Open Food Facts error ${res.status}`);
  const data = (await res.json()) as OffProductResponse;
  if (data.status !== 1 || !data.product) return null;
  return normalize(data.product, code);
}

/** Текстовый поиск продуктов (до [limit]). */
export async function searchProducts(
  query: string,
  limit = 20
): Promise<FoodProduct[]> {
  const url =
    `${OFF_BASE}/cgi/search.pl?search_terms=${encodeURIComponent(query)}` +
    `&search_simple=1&action=process&json=1&page_size=${limit}&fields=${FIELDS}`;
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
  if (!res.ok) throw new Error(`Open Food Facts error ${res.status}`);
  const data = (await res.json()) as OffSearchResponse;
  const products = data.products ?? [];
  const out: FoodProduct[] = [];
  for (const p of products) {
    const normalized = normalize(p, "");
    // нужен код и хоть какие-то калории, иначе для лога бесполезно
    if (normalized && normalized.code && normalized.per100g.calories !== null) {
      out.push(normalized);
    }
    if (out.length >= limit) break;
  }
  return out;
}
