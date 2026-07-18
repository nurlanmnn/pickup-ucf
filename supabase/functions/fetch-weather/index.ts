import "jsr:@supabase/functions-js/edge-runtime.d.ts";

export interface WeatherRequest {
  lat: number;
  lng: number;
  starts_at: string;
}

export interface WeatherSnapshot {
  summary: string;
  temp_f: number;
  precip_pct: number;
  fetched_at: string;
}

export interface OpenMeteoHourly {
  time: string[];
  temperature_2m: number[];
  precipitation_probability: number[];
  weather_code: number[];
}

export interface OpenMeteoResponse {
  hourly: OpenMeteoHourly;
}

const OPEN_METEO_BASE = "https://api.open-meteo.com/v1/forecast";

export function buildOpenMeteoUrl(lat: number, lng: number): string {
  const params = new URLSearchParams({
    latitude: String(lat),
    longitude: String(lng),
    hourly: "temperature_2m,precipitation_probability,weather_code",
    temperature_unit: "fahrenheit",
    timezone: "GMT",
    forecast_days: "16",
  });
  return `${OPEN_METEO_BASE}?${params}`;
}

export function weatherCodeToSummary(code: number): string {
  const map: Record<number, string> = {
    0: "Clear",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Foggy",
    48: "Foggy",
    51: "Light drizzle",
    53: "Drizzle",
    55: "Heavy drizzle",
    61: "Light rain",
    63: "Rain",
    65: "Heavy rain",
    66: "Freezing rain",
    67: "Freezing rain",
    71: "Light snow",
    73: "Snow",
    75: "Heavy snow",
    77: "Snow grains",
    80: "Light showers",
    81: "Showers",
    82: "Heavy showers",
    85: "Snow showers",
    86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with hail",
    99: "Thunderstorm with hail",
  };
  return map[code] ?? "Unknown";
}

export function parseForecastTime(time: string): number {
  const hasOffset = time.endsWith("Z") || /[+-]\d{2}:\d{2}$/.test(time);
  return new Date(hasOffset ? time : `${time}Z`).getTime();
}

export function findClosestHourIndex(times: string[], targetIso: string): number {
  const target = new Date(targetIso).getTime();
  if (Number.isNaN(target)) {
    throw new Error("Invalid starts_at");
  }

  let bestIndex = 0;
  let bestDiff = Infinity;

  for (let i = 0; i < times.length; i++) {
    const hourMs = parseForecastTime(times[i]);
    if (Number.isNaN(hourMs)) continue;
    const diff = Math.abs(hourMs - target);
    if (diff < bestDiff) {
      bestDiff = diff;
      bestIndex = i;
    }
  }

  return bestIndex;
}

export function parseOpenMeteoResponse(
  data: OpenMeteoResponse,
  startsAt: string,
  fetchedAt = new Date().toISOString(),
): WeatherSnapshot {
  const { hourly } = data;
  if (!hourly?.time?.length) {
    throw new Error("No hourly forecast data");
  }

  const idx = findClosestHourIndex(hourly.time, startsAt);
  const temp = hourly.temperature_2m[idx];
  const precip = hourly.precipitation_probability[idx] ?? 0;
  const code = hourly.weather_code[idx] ?? 0;

  if (typeof temp !== "number") {
    throw new Error("Missing temperature for forecast hour");
  }

  return {
    summary: weatherCodeToSummary(code),
    temp_f: Math.round(temp),
    precip_pct: Math.round(precip),
    fetched_at: fetchedAt,
  };
}

export function validateRequest(body: unknown): WeatherRequest {
  if (!body || typeof body !== "object") {
    throw new Error("Invalid JSON body");
  }

  const { lat, lng, starts_at } = body as Record<string, unknown>;

  if (typeof lat !== "number" || lat < -90 || lat > 90) {
    throw new Error("lat must be a number between -90 and 90");
  }
  if (typeof lng !== "number" || lng < -180 || lng > 180) {
    throw new Error("lng must be a number between -180 and 180");
  }
  if (typeof starts_at !== "string" || !starts_at.trim()) {
    throw new Error("starts_at must be a non-empty ISO timestamp");
  }
  if (Number.isNaN(new Date(starts_at).getTime())) {
    throw new Error("starts_at must be a valid ISO timestamp");
  }

  return { lat, lng, starts_at };
}

export interface HandlerDeps {
  fetchImpl?: typeof fetch;
}

export async function fetchWeather(
  lat: number,
  lng: number,
  startsAt: string,
  deps: HandlerDeps = {},
): Promise<WeatherSnapshot> {
  const fetchImpl = deps.fetchImpl ?? fetch;
  const res = await fetchImpl(buildOpenMeteoUrl(lat, lng));
  if (!res.ok) {
    throw new Error(`Open-Meteo request failed: ${res.status}`);
  }

  const data = await res.json() as OpenMeteoResponse;
  return parseOpenMeteoResponse(data, startsAt);
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function handler(req: Request, deps: HandlerDeps = {}): Promise<Response> {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  let input: WeatherRequest;
  try {
    input = validateRequest(body);
  } catch (error) {
    return jsonResponse({ error: (error as Error).message }, 400);
  }

  try {
    const snapshot = await fetchWeather(input.lat, input.lng, input.starts_at, deps);
    return jsonResponse(snapshot, 200);
  } catch (error) {
    return jsonResponse({ error: (error as Error).message }, 502);
  }
}

if (import.meta.main) {
  Deno.serve((req) => handler(req));
}
