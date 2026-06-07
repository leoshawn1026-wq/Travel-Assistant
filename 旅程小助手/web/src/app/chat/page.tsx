"use client";
import { useState, useRef, useEffect } from "react";
import api from "@/lib/api";
import {
  IconMessage,
  IconTrash,
  IconPlus,
  IconSend,
  IconMenu2,
  IconX,
  IconRobot,
  IconUser,
} from "@tabler/icons-react";

interface ChatMsg {
  role: "user" | "assistant";
  content: string;
}

interface Conversation {
  id: string;
  title: string;
  message_count: number;
  created_at: string;
  updated_at: string;
}

export default function ChatPage() {
  const deviceId =
    "web-" +
    (typeof window !== "undefined"
      ? localStorage.getItem("device_id") ||
        Math.random().toString(36).slice(2)
      : "unknown");

  useEffect(() => {
    if (typeof window !== "undefined" && !localStorage.getItem("device_id")) {
      localStorage.setItem("device_id", deviceId);
    }
  }, []);

  const [messages, setMessages] = useState<ChatMsg[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [streamingContent, setStreamingContent] = useState("");
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [currentConvId, setCurrentConvId] = useState<string | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const [historyMessages, setHistoryMessages] = useState<ChatMsg[]>([]);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // 加载对话列表
  useEffect(() => {
    loadConversations();
  }, []);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, streamingContent]);

  const loadConversations = async () => {
    try {
      const data = await api.listConversations(deviceId);
      if (data?.conversations) setConversations(data.conversations);
    } catch (e) {
      console.warn("[聊天] 加载对话列表失败:", e);
    }
  };

  const loadConversation = async (convId: string) => {
    try {
      const data = await api.getConversation(convId);
      if (data?.messages) {
        setMessages(data.messages);
        setCurrentConvId(convId);
      }
    } catch (e) {
      console.warn("[聊天] 加载对话失败:", e);
    }
  };

  const deleteConversation = async (convId: string) => {
    try {
      await api.deleteConversation(convId);
      if (currentConvId === convId) {
        setMessages([]);
        setCurrentConvId(null);
      }
      loadConversations();
    } catch (e) {
      console.warn("[聊天] 删除对话失败:", e);
    }
  };

  const newConversation = () => {
    setMessages([]);
    setCurrentConvId(null);
    setStreamingContent("");
  };

  const handleSend = async () => {
    const text = input.trim();
    if (!text || loading) return;
    setInput("");

    const userMsg: ChatMsg = { role: "user", content: text };
    const updatedMessages = [...messages, userMsg];
    setMessages(updatedMessages);
    setLoading(true);
    setStreamingContent("");

    try {
      const response = (await api.chatStream(
        updatedMessages.map((m) => ({ role: m.role, content: m.content })),
        deviceId
      )) as Response;
      const reader = response.body?.getReader();
      if (!reader) throw new Error("无法读取流");

      const decoder = new TextDecoder();
      let buffer = "";
      let assistantReply = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";

        for (const line of lines) {
          if (!line.startsWith("data: ")) continue;
          const data = line.slice(6).trim();
          if (!data) continue;
          try {
            const parsed = JSON.parse(data);
            if (parsed.t) {
              assistantReply += parsed.t;
              setStreamingContent(assistantReply);
            }
            if (parsed.e) {
              throw new Error(parsed.e);
            }
          } catch {}
        }
      }

      // 流结束，添加完整消息
      if (assistantReply) {
        const finalMessages: ChatMsg[] = [
          ...updatedMessages,
          { role: "assistant", content: assistantReply },
        ];
        setMessages(finalMessages);
        setStreamingContent("");

        // 保存对话
        try {
          if (currentConvId) {
            await api.saveConversation(deviceId, finalMessages, currentConvId);
          } else {
            const result = await api.saveConversation(deviceId, finalMessages, text.slice(0, 30));
            if (result?.conversation_id) setCurrentConvId(result.conversation_id);
          }
          loadConversations();
        } catch (e) {
          console.warn("[聊天] 保存对话失败:", e);
        }
      }
    } catch (e: any) {
      setMessages([...updatedMessages, { role: "assistant", content: "⚠️ " + (e.message || "请求失败") }]);
    } finally {
      setLoading(false);
      setStreamingContent("");
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  // 查看历史对话（非 conversation，而是旧版 chat_history）
  const loadHistoryMessages = async () => {
    try {
      const data = await api.getChatHistory(deviceId);
      if (data?.messages?.length > 0) {
        setHistoryMessages(data.messages);
        setShowHistory(true);
      } else {
        setHistoryMessages([]);
        setShowHistory(true);
      }
    } catch (e) {
      console.warn("[聊天] 加载历史记录失败:", e);
      setHistoryMessages([]);
      setShowHistory(true);
    }
  };

  const inputClass =
    "flex-1 px-4 py-3 border-[0.5px] border-[#ddd] rounded-xl text-sm focus:outline-none focus:border-wander-green transition-colors bg-cream text-wander-dark placeholder-wander-lighter";

  return (
    <div className="flex h-[calc(100vh-4rem)] max-w-6xl mx-auto">
      {/* Sidebar — 对话列表 */}
      <aside
        className={`${
          sidebarOpen ? "block" : "hidden"
        } md:block w-72 bg-white border-r-[0.5px] border-wander-border flex flex-col shrink-0`}
      >
        <div className="p-4 border-b-[0.5px] border-wander-border">
          <button
            onClick={newConversation}
            className="w-full flex items-center justify-center gap-2 bg-wander-dark text-cream py-2.5 rounded-xl text-sm font-medium hover:bg-wander-green transition-colors"
          >
            <IconPlus size={16} />
            新建对话
          </button>
        </div>
        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {conversations.length === 0 && (
            <p className="text-xs text-wander-lighter text-center py-8">
              暂无历史对话
            </p>
          )}
          {conversations.map((conv) => (
            <div
              key={conv.id}
              className={`group flex items-center justify-between p-2.5 rounded-xl cursor-pointer transition-colors ${
                currentConvId === conv.id
                  ? "bg-wander-green-light text-wander-green"
                  : "hover:bg-cream text-wander-gray"
              }`}
              onClick={() => {
                loadConversation(conv.id);
                setSidebarOpen(false);
              }}
            >
              <div className="flex items-center gap-2 min-w-0">
                <IconMessage size={14} className="shrink-0" />
                <span className="text-xs truncate">
                  {conv.title || `对话 ${conv.id?.slice(0, 8)}`}
                </span>
              </div>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  deleteConversation(conv.id);
                }}
                className="opacity-0 group-hover:opacity-100 text-wander-lighter hover:text-red-400 transition-all p-0.5"
              >
                <IconTrash size={12} />
              </button>
            </div>
          ))}
        </div>
        <div className="p-3 border-t-[0.5px] border-wander-border">
          <button
            onClick={loadHistoryMessages}
            className="w-full text-xs text-wander-light hover:text-wander-dark transition-colors flex items-center justify-center gap-1 py-1"
          >
            <IconMessage size={12} />
            查看旧版历史记录
          </button>
        </div>
      </aside>

      {/* Main Chat Area */}
      <div className="flex-1 flex flex-col bg-cream/30">
        {/* Mobile Header */}
        <div className="md:hidden flex items-center gap-3 p-3 border-b-[0.5px] border-wander-border bg-white">
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="text-wander-dark p-1"
          >
            <IconMenu2 size={20} />
          </button>
          <span className="font-medium text-sm text-wander-dark">AI 旅行助手</span>
          <button
            onClick={newConversation}
            className="ml-auto text-wander-green p-1"
          >
            <IconPlus size={18} />
          </button>
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto px-4 md:px-8 py-6 space-y-4">
          {messages.length === 0 && !streamingContent && (
            <div className="flex flex-col items-center justify-center h-full text-center">
              <div className="w-16 h-16 rounded-2xl bg-wander-green-light flex items-center justify-center mb-4">
                <IconRobot size={32} className="text-wander-green" />
              </div>
              <h2 className="font-heading text-xl font-bold text-wander-dark mb-2">
                AI 旅行助手
              </h2>
              <p className="text-wander-light text-sm max-w-md">
                有任何旅行问题都可以问我 — 目的地推荐、行程建议、美食攻略、预算规划...
              </p>
            </div>
          )}

          {messages.map((msg, i) => (
            <div
              key={i}
              className={`flex gap-3 ${msg.role === "user" ? "justify-end" : ""}`}
            >
              {msg.role === "assistant" && (
                <div className="w-8 h-8 rounded-full bg-wander-green flex items-center justify-center shrink-0">
                  <IconRobot size={16} className="text-white" />
                </div>
              )}
              <div
                className={`max-w-[75%] md:max-w-[65%] px-4 py-3 rounded-2xl text-sm leading-relaxed ${
                  msg.role === "user"
                    ? "bg-wander-dark text-cream rounded-br-md"
                    : "bg-white border-[0.5px] border-wander-border text-wander-dark rounded-bl-md"
                }`}
              >
                {msg.content}
              </div>
              {msg.role === "user" && (
                <div className="w-8 h-8 rounded-full bg-wander-dark flex items-center justify-center shrink-0">
                  <IconUser size={16} className="text-cream" />
                </div>
              )}
            </div>
          ))}

          {/* Streaming content */}
          {streamingContent && (
            <div className="flex gap-3">
              <div className="w-8 h-8 rounded-full bg-wander-green flex items-center justify-center shrink-0">
                <IconRobot size={16} className="text-white" />
              </div>
              <div className="max-w-[75%] md:max-w-[65%] px-4 py-3 rounded-2xl text-sm leading-relaxed bg-white border-[0.5px] border-wander-border text-wander-dark rounded-bl-md">
                {streamingContent}
                <span className="inline-block w-1.5 h-4 bg-wander-green ml-0.5 animate-pulse" />
              </div>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Input */}
        <div className="border-t-[0.5px] border-wander-border bg-white p-4 md:p-5">
          <div className="flex items-center gap-3 max-w-4xl mx-auto">
            <input
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="输入旅行问题..."
              className={inputClass}
              disabled={loading}
            />
            <button
              onClick={handleSend}
              disabled={loading || !input.trim()}
              className="w-11 h-11 rounded-xl bg-wander-dark text-cream flex items-center justify-center hover:bg-wander-green disabled:opacity-30 transition-colors shrink-0"
            >
              {loading ? (
                <span className="w-4 h-4 border-2 border-cream border-t-transparent rounded-full animate-spin" />
              ) : (
                <IconSend size={18} />
              )}
            </button>
          </div>
        </div>
      </div>

      {/* ── 历史对话记录 Modal ── */}
      {showHistory && (
        <div
          className="fixed inset-0 z-50 bg-black/30 flex items-center justify-center p-4"
          onClick={() => setShowHistory(false)}
        >
          <div
            className="bg-white rounded-2xl w-full max-w-lg max-h-[70vh] flex flex-col overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between p-5 border-b-[0.5px] border-wander-border">
              <h2 className="font-semibold text-sm text-wander-dark">历史对话记录</h2>
              <button
                onClick={() => setShowHistory(false)}
                className="text-wander-lighter hover:text-wander-dark"
              >
                <IconX size={18} />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto p-4 space-y-3">
              {historyMessages.length === 0 ? (
                <p className="text-xs text-wander-lighter text-center py-8">
                  暂无历史记录
                </p>
              ) : (
                historyMessages.map((msg, i) => (
                  <div
                    key={i}
                    className={`p-3 rounded-xl text-sm ${
                      msg.role === "user"
                        ? "bg-wander-dark/5 text-wander-dark"
                        : "bg-cream text-wander-gray"
                    }`}
                  >
                    <span className="text-xs font-medium block mb-1 text-wander-lighter">
                      {msg.role === "user" ? "👤 你" : "🤖 AI"}
                    </span>
                    {msg.content}
                  </div>
                ))
              )}
            </div>
            {historyMessages.length > 0 && (
              <div className="p-4 border-t-[0.5px] border-wander-border">
                <button
                  onClick={async () => {
                    await api.deleteChatHistory(deviceId);
                    setHistoryMessages([]);
                  }}
                  className="text-xs text-red-400 hover:text-red-500 flex items-center gap-1"
                >
                  <IconTrash size={12} />
                  清空历史记录
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
