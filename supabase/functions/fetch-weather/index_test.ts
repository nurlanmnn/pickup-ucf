import { assertEquals, assertStringIncludes } from "jsr:@std/assert";
import {
  buildOpenMeteoUrl,
  findClosestHourIndex,
  handler,
  parseForecastTime,
  parseOpenMeteoResponse,
  type OpenMeteoResponse,
  validateRequest,
  weatherCodeToSummary,
} from "./index.ts";

const MOCK_FETCHED_AT = "2026-07-18T18:00:00.000Z";

function mockOpenMeteoResponse(): OpenMeteoResponse {
  return {
    hourly: {
      time: [
        "2026-07-19T14:00",
        "2026-07-19T15:00",
        "2026-07-19T16:00",
        "2026-07-19T17:00",
      ],
      temperature_2m: [78.4, 81.2, 83.6, 80.1],
      precipitation_probability: [10, 25, 30, 45],
      weather_code: [1, 2, 63, 80],
    },
  };
}

function weatherRequest(body: Record<string, unknown>): Request {
  return new Request("https://example.supabase.co/functions/v1/fetch-weather", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("buildOpenMeteoUrl requests hourly forecast in Fahrenheit", () => {
  const url = buildOpenMeteoUrl(28.6024, -81.2001);
  assertStringIncludes(url, "api.open-meteo.com/v1/forecast");
  assertStringIncludes(url, "latitude=28.6024");
  assertStringIncludes(url, "longitude=-81.2001");
  assertStringIncludes(url, "temperature_unit=fahrenheit");
  assertStringIncludes(url, "timezone=GMT");
  assertStringIncludes(url, "hourly=temperature_2m%2Cprecipitation_probability%2Cweather_code");
});

Deno.test("parseForecastTime treats Open-Meteo hourly timestamps as UTC", () => {
  assertEquals(parseForecastTime("2026-07-19T16:00"), Date.parse("2026-07-19T16:00:00Z"));
});

Deno.test("weatherCodeToSummary maps WMO codes", () => {
  assertEquals(weatherCodeToSummary(0), "Clear");
  assertEquals(weatherCodeToSummary(63), "Rain");
  assertEquals(weatherCodeToSummary(999), "Unknown");
});

Deno.test("findClosestHourIndex picks nearest hourly slot", () => {
  const times = mockOpenMeteoResponse().hourly.time;
  assertEquals(findClosestHourIndex(times, "2026-07-19T15:30:00Z"), 1);
  assertEquals(findClosestHourIndex(times, "2026-07-19T16:45:00Z"), 3);
});

Deno.test("parseOpenMeteoResponse returns snapshot for closest hour", () => {
  const snapshot = parseOpenMeteoResponse(
    mockOpenMeteoResponse(),
    "2026-07-19T16:10:00Z",
    MOCK_FETCHED_AT,
  );

  assertEquals(snapshot, {
    summary: "Rain",
    temp_f: 84,
    precip_pct: 30,
    fetched_at: MOCK_FETCHED_AT,
  });
});

Deno.test("validateRequest rejects invalid coordinates and timestamps", () => {
  assertEquals(
    validateRequest({ lat: 28.6, lng: -81.2, starts_at: "2026-07-19T16:00:00Z" }),
    { lat: 28.6, lng: -81.2, starts_at: "2026-07-19T16:00:00Z" },
  );

  let message = "";
  try {
    validateRequest({ lat: 120, lng: 0, starts_at: "2026-07-19T16:00:00Z" });
  } catch (error) {
    message = (error as Error).message;
  }
  assertEquals(message, "lat must be a number between -90 and 90");
});

Deno.test("handler returns 405 for non-POST requests", async () => {
  const res = await handler(new Request("https://example.test", { method: "GET" }));
  assertEquals(res.status, 405);
});

Deno.test("handler returns 400 for invalid body", async () => {
  const res = await handler(weatherRequest({ lat: 28.6, lng: -81.2 }));
  assertEquals(res.status, 400);
  assertEquals(await res.json(), { error: "starts_at must be a non-empty ISO timestamp" });
});

Deno.test("handler parses mocked Open-Meteo response", async () => {
  const fetchImpl = async (input: string | URL | Request) => {
    const url = String(input);
    assertStringIncludes(url, "api.open-meteo.com/v1/forecast");
    return new Response(JSON.stringify(mockOpenMeteoResponse()), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };

  const res = await handler(
    weatherRequest({
      lat: 28.6024,
      lng: -81.2001,
      starts_at: "2026-07-19T16:10:00Z",
    }),
    { fetchImpl },
  );

  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.summary, "Rain");
  assertEquals(body.temp_f, 84);
  assertEquals(body.precip_pct, 30);
  assertEquals(typeof body.fetched_at, "string");
});

Deno.test("handler returns 502 when Open-Meteo fails", async () => {
  const fetchImpl = async () => new Response("upstream error", { status: 503 });

  const res = await handler(
    weatherRequest({
      lat: 28.6024,
      lng: -81.2001,
      starts_at: "2026-07-19T16:10:00Z",
    }),
    { fetchImpl },
  );

  assertEquals(res.status, 502);
  assertEquals(await res.json(), { error: "Open-Meteo request failed: 503" });
});
