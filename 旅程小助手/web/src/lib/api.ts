/** API 客户端 — 对接 FastAPI 后端 */
const BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1";

class ApiClient {
  private token: string | null = null;

  constructor() {
    if (typeof window !== "undefined") {
      this.token = localStorage.getItem("access_token");
    }
  }

  setToken(token: string | null) {
    this.token = token;
    if (typeof window !== "undefined") {
      if (token) localStorage.setItem("access_token", token);
      else localStorage.removeItem("access_token");
    }
  }

  getToken() { return this.token; }

  public async request<T>(
    method: string,
    path: string,
    body?: unknown,
    opts?: { stream?: boolean }
  ): Promise<T> {
    const headers: Record<string, string> = {};
    if (this.token) headers["Authorization"] = `Bearer ${this.token}`;

    const url = `${BASE_URL}${path}`;

    if (opts?.stream) {
      // SSE 流式请求
      headers["Content-Type"] = "application/json";
      const response = await fetch(url, {
        method,
        headers,
        body: body ? JSON.stringify(body) : undefined,
      });
      if (!response.ok) throw new Error(`API error: ${response.status}`);
      return response as unknown as T;
    }

    const res = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        ...headers,
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    const json = await res.json();
    if (json.code !== 0 && json.code !== undefined) {
      throw new Error(json.detail || json.message || "请求失败");
    }
    return json.data;
  }

  // ── 认证 ──
  async register(username: string, email: string, password: string) {
    return this.request<{ access_token: string; user: any }>("POST", "/auth/register", { username, email, password });
  }

  async login(username: string, password: string) {
    return this.request<{ access_token: string; user: any }>("POST", "/auth/login", { username, password });
  }

  async logout() {
    return this.request<any>("POST", "/auth/logout");
  }

  async getMe() {
    return this.request<any>("GET", "/auth/me");
  }

  // ── 用户 ──
  async getUserProfile(username: string) {
    return this.request<any>("GET", `/users/${username}`);
  }

  async getUserItineraries(username: string) {
    return this.request<any[]>("GET", `/users/${username}/itineraries`);
  }

  // ── 对比 ──
  async compareDestinations(params: any) {
    return this.request<any>("POST", "/compare/destinations", params);
  }

  compareDestinationsStream(params: any) {
    return this.request<Response>("POST", "/compare/destinations/stream", params, { stream: true });
  }

  async getCompareHistory(deviceId: string) {
    return this.request<any>("GET", `/compare/history?device_id=${deviceId}`);
  }

  async getCompareHistoryDetail(compId: string) {
    return this.request<any>("GET", `/compare/history/${compId}`);
  }

  async deleteCompareHistory(compId: string) {
    return this.request<any>("DELETE", `/compare/history/${compId}`);
  }

  // ── 行程 ──
  async generateItinerary(params: any) {
    return this.request<any>("POST", "/itinerary/generate", params);
  }

  generateItineraryStream(params: any) {
    return this.request<Response>("POST", "/itinerary/generate/stream", params, { stream: true });
  }

  // ── 聊天 ──
  async chat(messages: { role: string; content: string }[], deviceId = "") {
    return this.request<any>("POST", "/chat", { messages, stream: false, device_id: deviceId });
  }

  chatStream(messages: { role: string; content: string }[], deviceId = "") {
    return this.request<Response>("POST", "/chat/stream", { messages, stream: true, device_id: deviceId }, { stream: true });
  }

  async getChatHistory(deviceId: string) {
    return this.request<any>("GET", `/chat/history?device_id=${deviceId}`);
  }

  async saveChatHistory(deviceId: string, messages: { role: string; content: string }[]) {
    return this.request<any>("POST", "/chat/history", { device_id: deviceId, messages });
  }

  async deleteChatHistory(deviceId: string) {
    return this.request<any>("DELETE", `/chat/history?device_id=${deviceId}`);
  }

  async listConversations(deviceId: string) {
    return this.request<any>("GET", `/chat/conversations?device_id=${deviceId}`);
  }

  async getConversation(convId: string) {
    return this.request<any>("GET", `/chat/conversations/${convId}`);
  }

  async saveConversation(deviceId: string, messages: { role: string; content: string }[], title = "") {
    return this.request<any>("POST", "/chat/conversations", { device_id: deviceId, messages, title });
  }

  async deleteConversation(convId: string) {
    return this.request<any>("DELETE", `/chat/conversations/${convId}`);
  }

  // ── 社交 ──
  async saveItinerary(data: { title: string; destination: string; itinerary_data: any; is_public?: boolean }) {
    return this.request<any>("POST", "/social/itineraries", data);
  }

  async getFeed(page = 1, destination = "") {
    const params = new URLSearchParams({ page: String(page), page_size: "20" });
    if (destination) params.set("destination", destination);
    return this.request<any>("GET", `/social/feed?${params}`);
  }

  async getSharedItinerary(shareToken: string) {
    return this.request<any>("GET", `/social/share/${shareToken}`);
  }

  async likeItinerary(itineraryId: number) {
    return this.request<{ like_count: number }>("POST", `/social/itineraries/${itineraryId}/like`);
  }

  async unlikeItinerary(itineraryId: number) {
    return this.request<void>("DELETE", `/social/itineraries/${itineraryId}/like`);
  }

  async addComment(itineraryId: number, content: string) {
    return this.request<any>("POST", `/social/itineraries/${itineraryId}/comments`, { content });
  }

  async getComments(itineraryId: number) {
    return this.request<any>("GET", `/social/itineraries/${itineraryId}/comments`);
  }

  async followUser(userId: number) {
    return this.request<void>("POST", `/social/follow/${userId}`);
  }

  async unfollowUser(userId: number) {
    return this.request<void>("DELETE", `/social/follow/${userId}`);
  }

  // ── 出行查询 ──
  async getWeather(city: string) {
    return this.request<any>("GET", `/travel/weather?city=${encodeURIComponent(city)}`);
  }

  async getHotels(city: string, checkIn = "", checkOut = "") {
    const params = new URLSearchParams({ city });
    if (checkIn) params.set("check_in", checkIn);
    if (checkOut) params.set("check_out", checkOut);
    return this.request<any>("GET", `/travel/hotels?${params}`);
  }

  async getRestaurants(city: string, cuisine = "") {
    const params = new URLSearchParams({ city });
    if (cuisine) params.set("cuisine", cuisine);
    return this.request<any>("GET", `/travel/restaurants?${params}`);
  }

  async getFlights(fromCity: string, toCity: string, date = "") {
    const params = new URLSearchParams({ from_city: fromCity, to_city: toCity });
    if (date) params.set("date", date);
    return this.request<any>("GET", `/travel/flights?${params}`);
  }

  async getTrains(fromStation: string, toStation: string, date = "") {
    const params = new URLSearchParams({ from_station: fromStation, to_station: toStation });
    if (date) params.set("date", date);
    return this.request<any>("GET", `/travel/trains?${params}`);
  }

  // ── POI 搜索 ──
  async searchPoi(keywords: string, city = "") {
    const params = new URLSearchParams({ keywords });
    if (city) params.set("city", city);
    return this.request<any>("GET", `/poi/search?${params}`);
  }
}

export const api = new ApiClient();
export default api;
