"use client";

import { useState } from "react";
import {
  Loader2,
  Trash2,
  RefreshCw,
  Wifi,
  WifiOff,
  Save,
  X,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { useQueryClient } from "@tanstack/react-query";
import { useSettingsStore } from "@/stores/settings-store";
import {
  useSubscriptions,
  useUnsubscribe,
  useKnowledgeBases,
} from "@/lib/queries";
import {
  clearSubscriptions,
  getSubscriptions,
  saveSubscription,
} from "@/lib/subscription-store";
import type { Subscription, KnowledgeBase } from "@/types";

export default function SettingsPage() {
  const { apiKey, clientId, setApiKey, setClientId, clear: clearSettings } = useSettingsStore();
  const [inputApiKey, setInputApiKey] = useState(apiKey);
  const [inputClientId, setInputClientId] = useState(clientId);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<"success" | "error" | null>(null);

  const queryClient = useQueryClient();
  const { data: subscriptions } = useSubscriptions();
  const unsubscribeMut = useUnsubscribe();
  const { refetch: refetchKnowledgeBases, isFetching: isSyncing } = useKnowledgeBases();

  const subList: Subscription[] = subscriptions ? Object.values(subscriptions) : [];

  // Save API credentials
  const handleSave = () => {
    if (!inputApiKey.trim() || !inputClientId.trim()) {
      toast.error("请填写完整的 API Key 和 Client ID");
      return;
    }
    setApiKey(inputApiKey.trim());
    setClientId(inputClientId.trim());
    setTestResult(null);
    toast.success("配置已保存");
  };

  // Test connection by calling /api/getnote/notes
  const handleTest = async () => {
    const key = inputApiKey.trim() || apiKey;
    const cid = inputClientId.trim() || clientId;
    if (!key || !cid) {
      toast.error("请先配置 API Key 和 Client ID");
      return;
    }
    setTesting(true);
    setTestResult(null);
    try {
      const res = await fetch("/api/getnote/notes", {
        headers: {
          "Content-Type": "application/json",
          "X-Api-Key": key,
          "X-Client-ID": cid,
        },
      });
      const body = await res.json();
      if (body.success) {
        setTestResult("success");
        toast.success("连接成功");
      } else {
        setTestResult("error");
        toast.error(`连接失败: ${body.error?.message ?? "未知错误"}`);
      }
    } catch {
      setTestResult("error");
      toast.error("网络请求失败，请检查配置");
    } finally {
      setTesting(false);
    }
  };

  // Sync from Get笔记 knowledge bases
  const handleSyncKnowledgeBases = async () => {
    const result = await refetchKnowledgeBases();
    if (!result.data) {
      toast.error("获取知识库失败，请检查 API 配置");
      return;
    }
    const topics: KnowledgeBase[] = result.data.topics ?? [];
    if (topics.length === 0) {
      toast.info("未发现任何知识库");
      return;
    }
    // Rebuild localStorage subscription mapping from knowledge bases
    const existing = getSubscriptions();
    let syncCount = 0;
    for (const kb of topics) {
      // Only add if not already subscribed
      if (!existing[kb.topic_id]) {
        const sub: Subscription = {
          xyzrankId: kb.topic_id,
          topicId: kb.topic_id,
          podcastName: kb.name,
          rssUrl: "",
          logoUrl: "",
          category: "",
        };
        saveSubscription(sub);
        syncCount++;
      }
    }
    queryClient.invalidateQueries({ queryKey: ["subscriptions"] });
    toast.success(`已同步 ${syncCount} 个新的知识库订阅`);
  };

  // Clear all subscription data
  const handleClearSubscriptions = () => {
    clearSubscriptions();
    queryClient.invalidateQueries({ queryKey: ["subscriptions"] });
    toast.success("已清除所有订阅数据");
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight">设置</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          管理 Get笔记 API 配置和播客订阅
        </p>
      </div>

      {/* API Configuration */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">API 配置</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium">API Key</label>
            <Input
              type="password"
              value={inputApiKey}
              onChange={(e) => setInputApiKey(e.target.value)}
              placeholder="输入 Get笔记 API Key"
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium">Client ID</label>
            <Input
              type="password"
              value={inputClientId}
              onChange={(e) => setInputClientId(e.target.value)}
              placeholder="输入 Client ID"
            />
          </div>
          <div className="flex items-center gap-3">
            <Button size="sm" onClick={handleSave}>
              <Save className="mr-1.5 h-3.5 w-3.5" />
              保存配置
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={handleTest}
              disabled={testing}
            >
              {testing ? (
                <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
              ) : testResult === "success" ? (
                <Wifi className="mr-1.5 h-3.5 w-3.5 text-green-600" />
              ) : testResult === "error" ? (
                <WifiOff className="mr-1.5 h-3.5 w-3.5 text-red-600" />
              ) : (
                <Wifi className="mr-1.5 h-3.5 w-3.5" />
              )}
              测试连接
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Subscribed Podcasts */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">已订阅的播客</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {subList.length > 0 ? (
            <ul className="space-y-2">
              {subList.map((sub) => (
                <li
                  key={sub.xyzrankId}
                  className="flex items-center justify-between gap-3 rounded-md border px-3 py-2"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    {sub.logoUrl && (
                      <img
                        src={sub.logoUrl}
                        alt={sub.podcastName}
                        className="h-8 w-8 rounded-md object-cover shrink-0"
                      />
                    )}
                    <div className="min-w-0">
                      <p className="text-sm font-medium truncate">
                        {sub.podcastName}
                      </p>
                      {sub.category && (
                        <Badge variant="outline" className="mt-0.5 text-[10px]">
                          {sub.category}
                        </Badge>
                      )}
                    </div>
                  </div>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="shrink-0 h-8 w-8 p-0 text-destructive hover:bg-destructive/10 hover:text-destructive"
                    onClick={() =>
                      unsubscribeMut.mutate(sub.xyzrankId, {
                        onSuccess: () => toast.success(`已取消订阅: ${sub.podcastName}`),
                        onError: (err) => toast.error(`取消订阅失败: ${err.message}`),
                      })
                    }
                    disabled={unsubscribeMut.isPending}
                  >
                    <X className="h-3.5 w-3.5" />
                  </Button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-muted-foreground py-4 text-center">
              暂无订阅
            </p>
          )}
          <div className="flex items-center gap-3 pt-2 border-t">
            <Button
              variant="outline"
              size="sm"
              onClick={handleSyncKnowledgeBases}
              disabled={isSyncing}
            >
              {isSyncing ? (
                <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
              ) : (
                <RefreshCw className="mr-1.5 h-3.5 w-3.5" />
              )}
              从 Get笔记 同步
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="text-destructive hover:bg-destructive/10 hover:text-destructive"
              onClick={handleClearSubscriptions}
            >
              <Trash2 className="mr-1.5 h-3.5 w-3.5" />
              清除所有订阅数据
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
