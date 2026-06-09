/**
 * Food routes (Open Food Facts barcode/search). OFF module is mocked — no real
 * network calls (QA rule: no external calls in tests).
 */
import { buildServer } from "../../backend/src/app";
import type { FastifyInstance } from "fastify";
import { registerUser, cleanupUser } from "../helpers";

jest.mock("../../backend/src/food/openFoodFacts", () => ({
  lookupBarcode: jest.fn(),
  searchProducts: jest.fn(),
}));
import {
  lookupBarcode,
  searchProducts,
} from "../../backend/src/food/openFoodFacts";

const mockLookup = lookupBarcode as jest.Mock;
const mockSearch = searchProducts as jest.Mock;

let app: FastifyInstance;
const userIds: string[] = [];
let token: string;

const sampleProduct = {
  code: "737628064502",
  name: "Thai peanut noodle kit",
  brand: "Simply Asia",
  per100g: {
    calories: 389,
    protein: 12,
    fat: 6.5,
    carbs: 71,
    sugar: 8,
    fiber: 3.5,
  },
};

beforeAll(async () => {
  app = await buildServer();
  await app.ready();
  const user = await registerUser(app);
  userIds.push(user.userId);
  token = user.token;
});

afterAll(async () => {
  for (const id of userIds) await cleanupUser(id);
  await app.close();
});

beforeEach(() => {
  mockLookup.mockReset();
  mockSearch.mockReset();
});

test("barcode lookup → 200 with normalized per_100g", async () => {
  mockLookup.mockResolvedValue(sampleProduct);
  const res = await app.inject({
    method: "GET",
    url: "/api/v1/food/barcode/737628064502",
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(res.statusCode).toBe(200);
  const body = res.json<{ name: string; per_100g: { calories: number } }>();
  expect(body.name).toBe("Thai peanut noodle kit");
  expect(body.per_100g.calories).toBe(389);
});

test("barcode not found → 404", async () => {
  mockLookup.mockResolvedValue(null);
  const res = await app.inject({
    method: "GET",
    url: "/api/v1/food/barcode/000000000000",
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(res.statusCode).toBe(404);
});

test("invalid barcode → 400 (no OFF call)", async () => {
  const res = await app.inject({
    method: "GET",
    url: "/api/v1/food/barcode/not-a-code",
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(res.statusCode).toBe(400);
  expect(mockLookup).not.toHaveBeenCalled();
});

test("search → 200 with products", async () => {
  mockSearch.mockResolvedValue([sampleProduct]);
  const res = await app.inject({
    method: "GET",
    url: "/api/v1/food/search?q=noodle",
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(res.statusCode).toBe(200);
  const body = res.json<{ products: Array<{ code: string }> }>();
  expect(body.products).toHaveLength(1);
  expect(body.products[0]?.code).toBe("737628064502");
});

test("search without q → 400", async () => {
  const res = await app.inject({
    method: "GET",
    url: "/api/v1/food/search",
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(res.statusCode).toBe(400);
});

test("food endpoints require auth → 401", async () => {
  const res = await app.inject({
    method: "GET",
    url: "/api/v1/food/search?q=noodle",
  });
  expect(res.statusCode).toBe(401);
});
