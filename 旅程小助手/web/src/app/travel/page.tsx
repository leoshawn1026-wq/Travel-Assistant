"use client";
import { useState } from "react";
import api from "@/lib/api";
import {
  IconSun,
  IconBuilding,
  IconBuildingStore,
  IconPlane,
  IconTrain,
  IconSearch,
  IconMapPin,
  IconStar,
  IconClock,
  IconWind,
  IconDroplet,
} from "@tabler/icons-react";

type Tab = "weather" | "hotels" | "restaurants" | "flights" | "trains";

const TABS: { key: Tab; label: string; icon: any }[] = [
  { key: "weather", label: "天气", icon: IconSun },
  { key: "hotels", label: "酒店", icon: IconBuilding },
  { key: "restaurants", label: "餐厅", icon: IconBuildingStore },
  { key: "flights", label: "机票", icon: IconPlane },
  { key: "trains", label: "火车票", icon: IconTrain },
];

const ICON_SIZE = 18;

export default function TravelPage() {
  const [tab, setTab] = useState<Tab>("weather");

  // Weather
  const [weatherCity, setWeatherCity] = useState("");
  const [weatherData, setWeatherData] = useState<any>(null);
  const [weatherLoading, setWeatherLoading] = useState(false);

  // Hotels
  const [hotelCity, setHotelCity] = useState("");
  const [hotelCheckIn, setHotelCheckIn] = useState("");
  const [hotelCheckOut, setHotelCheckOut] = useState("");
  const [hotels, setHotels] = useState<any[]>([]);
  const [hotelLoading, setHotelLoading] = useState(false);

  // Restaurants
  const [restCity, setRestCity] = useState("");
  const [restCuisine, setRestCuisine] = useState("");
  const [restaurants, setRestaurants] = useState<any[]>([]);
  const [restLoading, setRestLoading] = useState(false);

  // Flights
  const [flightFrom, setFlightFrom] = useState("");
  const [flightTo, setFlightTo] = useState("");
  const [flightDate, setFlightDate] = useState("");
  const [flights, setFlights] = useState<any[]>([]);
  const [flightLoading, setFlightLoading] = useState(false);

  // Trains
  const [trainFrom, setTrainFrom] = useState("");
  const [trainTo, setTrainTo] = useState("");
  const [trainDate, setTrainDate] = useState("");
  const [trains, setTrains] = useState<any[]>([]);
  const [trainLoading, setTrainLoading] = useState(false);

  const [error, setError] = useState("");

  // ── 天气 ──
  const searchWeather = async () => {
    if (!weatherCity.trim()) return;
    setError(""); setWeatherLoading(true);
    try {
      const data = await api.getWeather(weatherCity.trim());
      setWeatherData(data);
    } catch (e: any) { setError(e.message); }
    finally { setWeatherLoading(false); }
  };

  // ── 酒店 ──
  const searchHotels = async () => {
    if (!hotelCity.trim()) return;
    setError(""); setHotelLoading(true);
    try {
      const data = await api.getHotels(hotelCity.trim(), hotelCheckIn, hotelCheckOut);
      setHotels(data?.items || []);
    } catch (e: any) { setError(e.message); }
    finally { setHotelLoading(false); }
  };

  // ── 餐厅 ──
  const searchRestaurants = async () => {
    if (!restCity.trim()) return;
    setError(""); setRestLoading(true);
    try {
      const data = await api.getRestaurants(restCity.trim(), restCuisine);
      setRestaurants(data?.items || []);
    } catch (e: any) { setError(e.message); }
    finally { setRestLoading(false); }
  };

  // ── 机票 ──
  const searchFlights = async () => {
    if (!flightFrom.trim() || !flightTo.trim()) { setError("请填写出发和到达城市"); return; }
    setError(""); setFlightLoading(true);
    try {
      const data = await api.getFlights(flightFrom.trim(), flightTo.trim(), flightDate);
      setFlights(data?.items || []);
    } catch (e: any) { setError(e.message); }
    finally { setFlightLoading(false); }
  };

  // ── 火车票 ──
  const searchTrains = async () => {
    if (!trainFrom.trim() || !trainTo.trim()) { setError("请填写出发和到达站"); return; }
    setError(""); setTrainLoading(true);
    try {
      const data = await api.getTrains(trainFrom.trim(), trainTo.trim(), trainDate);
      setTrains(data?.items || []);
    } catch (e: any) { setError(e.message); }
    finally { setTrainLoading(false); }
  };

  const inputClass = "w-full px-4 py-2.5 border-[0.5px] border-[#ddd] rounded-xl text-sm focus:outline-none focus:border-wander-green transition-colors bg-cream text-wander-dark placeholder-wander-lighter";
  const sp = <span className="w-5 h-5 border-2 border-wander-green border-t-transparent rounded-full animate-spin inline-block" />;
  const TRUNCATE = "whitespace-nowrap overflow-hidden text-ellipsis";

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-8 py-8 space-y-6">
      {/* Header */}
      <div className="text-center">
        <h1 className="font-heading text-3xl md:text-4xl font-bold text-wander-dark mb-2">
          出行助手
        </h1>
        <p className="text-wander-light text-sm max-w-md mx-auto">
          实时天气、酒店推荐、餐厅评分、机票火车票比价，一站式查询
        </p>
      </div>

      {/* Tabs */}
      <div className="flex overflow-x-auto gap-1 bg-white rounded-2xl p-1.5 border-[0.5px] border-wander-border">
        {TABS.map((t) => {
          const Icon = t.icon;
          const active = tab === t.key;
          return (
            <button
              key={t.key}
              onClick={() => { setTab(t.key); setError(""); }}
              className={`flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-sm font-medium transition-colors whitespace-nowrap ${
                active ? "bg-wander-dark text-cream" : "text-wander-gray hover:bg-cream"
              }`}
            >
              <Icon size={16} />
              {t.label}
            </button>
          );
        })}
      </div>

      {error && <p className="text-red-500 text-sm bg-red-50 p-3 rounded-xl">{error}</p>}

      {/* ── Weather Tab ── */}
      {tab === "weather" && (
        <div className="space-y-4">
          <div className="flex gap-3">
            <input value={weatherCity} onChange={e => setWeatherCity(e.target.value)}
              placeholder="输入城市名，如：成都" className={inputClass}
              onKeyDown={e => e.key === 'Enter' && searchWeather()} />
            <button onClick={searchWeather} disabled={weatherLoading}
              className="px-6 py-2.5 bg-wander-dark text-cream rounded-xl text-sm font-medium hover:bg-wander-green disabled:opacity-50 transition-colors flex items-center gap-2 shrink-0">
              {weatherLoading ? sp : <><IconSearch size={16} /> 查询</>}
            </button>
          </div>

          {weatherData && (
            <div className="bg-white rounded-2xl p-6 border-[0.5px] border-wander-border">
              <div className="flex items-center gap-3 mb-5">
                <span className="text-4xl">
                  {weatherData.weather?.includes("晴") ? "☀️" : weatherData.weather?.includes("雨") ? "🌧️" : weatherData.weather?.includes("云") ? "☁️" : "🌤️"}
                </span>
                <div>
                  <h2 className="font-heading text-xl font-bold text-wander-dark">{weatherData.city || weatherCity}</h2>
                  <p className="text-wander-light text-sm">{weatherData.weather}</p>
                </div>
                <span className="ml-auto font-heading text-5xl font-bold text-wander-green">{weatherData.temperature}°C</span>
              </div>
              <div className="grid grid-cols-3 gap-4">
                {[
                  { label: "体感温度", value: `${weatherData.temperature || "-"}°C`, icon: IconSun },
                  { label: "风向风力", value: weatherData.wind || "-", icon: IconWind },
                  { label: "湿度", value: weatherData.humidity ? `${weatherData.humidity}%` : "-", icon: IconDroplet },
                ].map((item, i) => (
                  <div key={i} className="bg-cream rounded-xl p-3 text-center">
                    <item.icon size={16} className="mx-auto text-wander-light mb-1" />
                    <p className="text-xs text-wander-light">{item.label}</p>
                    <p className="text-sm font-medium text-wander-dark mt-0.5">{item.value}</p>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── Hotels Tab ── */}
      {tab === "hotels" && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl p-5 border-[0.5px] border-wander-border space-y-3">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              <input value={hotelCity} onChange={e => setHotelCity(e.target.value)} placeholder="城市" className={inputClass} />
              <input type="date" value={hotelCheckIn} onChange={e => setHotelCheckIn(e.target.value)} className={inputClass} />
              <input type="date" value={hotelCheckOut} onChange={e => setHotelCheckOut(e.target.value)} className={inputClass} />
            </div>
            <button onClick={searchHotels} disabled={hotelLoading}
              className="w-full py-2.5 bg-wander-dark text-cream rounded-xl text-sm font-medium hover:bg-wander-green disabled:opacity-50 transition-colors flex items-center justify-center gap-2">
              {hotelLoading ? sp : <><IconSearch size={16} /> 搜索酒店</>}
            </button>
          </div>

          {hotels.length > 0 && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {hotels.map((h, i) => (
                <div key={i} className="bg-white rounded-2xl p-5 border-[0.5px] border-wander-border hover:shadow-sm transition-shadow">
                  <div className="flex items-start justify-between mb-2">
                    <h3 className="font-medium text-sm text-wander-dark">{h.name}</h3>
                    <span className="flex items-center gap-1 text-xs font-medium text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full">
                      <IconStar size={12} /> {h.rating}
                    </span>
                  </div>
                  <p className="text-xs text-wander-lighter mb-1"><IconMapPin size={12} className="inline mr-0.5" />{h.address}</p>
                  <p className="text-xs text-wander-gray mb-2">{h.type} · {h.price_display || h.price}</p>
                  {h.tags && <div className="flex flex-wrap gap-1 mb-2">{h.tags.map((t: string, j: number) => (
                    <span key={j} className="text-xs bg-cream text-wander-gray px-2 py-0.5 rounded-full">{t}</span>
                  ))}</div>}
                  {h.tips && <p className="text-xs text-wander-light">💡 {h.tips}</p>}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ── Restaurants Tab ── */}
      {tab === "restaurants" && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl p-5 border-[0.5px] border-wander-border space-y-3">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <input value={restCity} onChange={e => setRestCity(e.target.value)} placeholder="城市" className={inputClass} />
              <input value={restCuisine} onChange={e => setRestCuisine(e.target.value)} placeholder="菜系偏好（可选）如：川菜、粤菜" className={inputClass} />
            </div>
            <button onClick={searchRestaurants} disabled={restLoading}
              className="w-full py-2.5 bg-wander-dark text-cream rounded-xl text-sm font-medium hover:bg-wander-green disabled:opacity-50 transition-colors flex items-center justify-center gap-2">
              {restLoading ? sp : <><IconSearch size={16} /> 搜索餐厅</>}
            </button>
          </div>

          {restaurants.length > 0 && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {restaurants.map((r, i) => (
                <div key={i} className={`bg-white rounded-2xl p-5 border-[0.5px] border-wander-border hover:shadow-sm transition-shadow ${
                  r.type === "local" ? "border-l-2 border-l-wander-green" : r.type === "street_food" ? "border-l-2 border-l-amber-400" : ""
                }`}>
                  <div className="flex items-start justify-between mb-1">
                    <h3 className="font-medium text-sm text-wander-dark">{r.name}</h3>
                    <span className="flex items-center gap-1 text-xs font-medium text-amber-600 bg-amber-50 px-2 py-0.5 rounded-full shrink-0">
                      <IconStar size={12} /> {r.rating}
                    </span>
                  </div>
                  <p className="text-xs text-wander-lighter mb-1"><IconMapPin size={12} className="inline mr-0.5" />{r.address}</p>
                  <div className="flex items-center gap-2 text-xs text-wander-gray mb-2">
                    <span className="bg-cream px-2 py-0.5 rounded-full">{r.cuisine}</span>
                    <span>{r.price_display || r.price}</span>
                    {r.type === "local" && <span className="text-wander-green">· 本地推荐</span>}
                  </div>
                  {r.tags && <div className="flex flex-wrap gap-1 mb-2">{r.tags.map((t: string, j: number) => (
                    <span key={j} className="text-xs bg-cream text-wander-gray px-2 py-0.5 rounded-full">{t}</span>
                  ))}</div>}
                  {r.tips && <p className="text-xs text-wander-light">💡 {r.tips}</p>}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ── Flights Tab ── */}
      {tab === "flights" && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl p-5 border-[0.5px] border-wander-border space-y-3">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              <input value={flightFrom} onChange={e => setFlightFrom(e.target.value)} placeholder="出发城市" className={inputClass} />
              <input value={flightTo} onChange={e => setFlightTo(e.target.value)} placeholder="到达城市" className={inputClass} />
              <input type="date" value={flightDate} onChange={e => setFlightDate(e.target.value)} className={inputClass} />
            </div>
            <button onClick={searchFlights} disabled={flightLoading}
              className="w-full py-2.5 bg-wander-dark text-cream rounded-xl text-sm font-medium hover:bg-wander-green disabled:opacity-50 transition-colors flex items-center justify-center gap-2">
              {flightLoading ? sp : <><IconSearch size={16} /> 搜索航班</>}
            </button>
          </div>

          {flights.length > 0 && (
            <div className="space-y-3">
              {flights.map((f, i) => (
                <div key={i} className="bg-white rounded-2xl p-5 border-[0.5px] border-wander-border hover:shadow-sm transition-shadow">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-medium text-wander-dark bg-cream px-2 py-0.5 rounded">{f.airline}</span>
                      <span className="text-xs text-wander-lighter">{f.flight_no}</span>
                    </div>
                    <span className="font-heading text-lg font-bold text-wander-green">{f.price}</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <div className="text-center">
                      <p className="text-lg font-bold text-wander-dark">{f.depart_time}</p>
                      <p className="text-xs text-wander-light">{f.departure}</p>
                    </div>
                    <div className="flex-1 flex flex-col items-center">
                      <span className="text-xs text-wander-lighter">{f.duration}</span>
                      <div className="w-full h-[1px] bg-[#ddd] relative my-1">
                        <span className="absolute inset-x-0 top-1/2 -translate-y-1/2 text-center">✈️</span>
                      </div>
                    </div>
                    <div className="text-center">
                      <p className="text-lg font-bold text-wander-dark">{f.arrive_time}</p>
                      <p className="text-xs text-wander-light">{f.arrival}</p>
                    </div>
                  </div>
                  {f.tips && <p className="text-xs text-wander-light mt-2">💡 {f.tips}</p>}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ── Trains Tab ── */}
      {tab === "trains" && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl p-5 border-[0.5px] border-wander-border space-y-3">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              <input value={trainFrom} onChange={e => setTrainFrom(e.target.value)} placeholder="出发站/城市" className={inputClass} />
              <input value={trainTo} onChange={e => setTrainTo(e.target.value)} placeholder="到达站/城市" className={inputClass} />
              <input type="date" value={trainDate} onChange={e => setTrainDate(e.target.value)} className={inputClass} />
            </div>
            <button onClick={searchTrains} disabled={trainLoading}
              className="w-full py-2.5 bg-wander-dark text-cream rounded-xl text-sm font-medium hover:bg-wander-green disabled:opacity-50 transition-colors flex items-center justify-center gap-2">
              {trainLoading ? sp : <><IconSearch size={16} /> 搜索车次</>}
            </button>
          </div>

          {trains.length > 0 && (
            <div className="space-y-3">
              {trains.map((t, i) => (
                <div key={i} className="bg-white rounded-2xl p-5 border-[0.5px] border-wander-border hover:shadow-sm transition-shadow">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2">
                      <span className={`text-xs font-medium px-2 py-0.5 rounded ${
                        t.type === "高铁" ? "bg-blue-50 text-blue-600" : t.type === "动车" ? "bg-green-50 text-green-600" : "bg-gray-50 text-gray-600"
                      }`}>{t.train_no} {t.type}</span>
                      <span className="text-xs text-wander-lighter">
                        <IconClock size={12} className="inline mr-0.5" />{t.duration}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-3 mb-4">
                    <div className="text-center">
                      <p className="text-lg font-bold text-wander-dark">{t.depart_time}</p>
                      <p className="text-xs text-wander-light">{t.departure}</p>
                    </div>
                    <div className="flex-1 flex flex-col items-center">
                      <div className="w-full h-[1px] border-t border-dashed border-[#ddd] relative my-2">
                        <span className="absolute inset-x-0 top-1/2 -translate-y-1/2 text-center text-xs">🚄</span>
                      </div>
                    </div>
                    <div className="text-center">
                      <p className="text-lg font-bold text-wander-dark">{t.arrive_time}</p>
                      <p className="text-xs text-wander-light">{t.arrival}</p>
                    </div>
                  </div>
                  <div className="grid grid-cols-3 gap-2">
                    {t.seat_types?.map((s: any, j: number) => (
                      <div key={j} className="bg-cream rounded-xl p-2.5 text-center">
                        <p className="text-xs text-wander-light">{s.type}</p>
                        <p className="text-sm font-bold text-wander-green">{s.price}</p>
                        <p className={`text-xs ${s.available === '已售罄' ? 'text-red-400' : s.available === '充足' ? 'text-green-500' : 'text-amber-500'}`}>
                          {s.available}
                        </p>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Empty state */}
      {tab !== "weather" && (
        (tab === "hotels" && hotels.length === 0 && !hotelLoading) ||
        (tab === "restaurants" && restaurants.length === 0 && !restLoading) ||
        (tab === "flights" && flights.length === 0 && !flightLoading) ||
        (tab === "trains" && trains.length === 0 && !trainLoading)
      ) && (
        <div className="text-center py-12 text-wander-light">
          <p className="text-sm">输入信息后点击搜索</p>
        </div>
      )}
    </div>
  );
}
