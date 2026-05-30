"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import type { SaveNoteRequest, Subscription, NoteListResponse, NoteDetail, TaskProgress, KnowledgeListResponse, KnowledgeNotesResponse, RecallResponse, SaveNoteResponse } from "@/types";
import * as subscriptionStore from "@/lib/subscription-store";

// ========== Query Keys ==========

export const queryKeys = {
  notes: {
    all: ["notes"] as const,
    list: (cursor?: string) => [...queryKeys.notes.all, cursor] as const,
    detail: (id: string) => ["notes", id] as const,
  },
  knowledge: {
    all: ["knowledge"] as const,
    list: (page?: number) => [...queryKeys.knowledge.all, page] as const,
    notes: (topicId: string, page?: number) =>
      ["knowledge", topicId, "notes", page] as const,
  },
  rankings: {
    all: ["rankings"] as const,
    page: (offset: number, limit: number) =>
      ["rankings", offset, limit] as const,
  },
  feed: (url: string) => ["feed", url] as const,
  recall: {
    global: (query: string) => ["recall", query] as const,
    knowledge: (topicId: string, query: string) =>
      ["recall", topicId, query] as const,
  },
  task: (taskId: string) => ["task", taskId] as const,
  subscriptions: ["subscriptions"] as const,
};

// ========== Settings Store Import ==========

// We need the settings store for API credentials.
// Import lazily to avoid circular deps.
import type { useSettingsStore } from "@/stores/settings-store";

type SettingsStore = typeof useSettingsStore;

let _settingsStore: SettingsStore | null = null;
async function getSettingsStore(): Promise<SettingsStore> {
  if (!_settingsStore) {
    const mod = await import("@/stores/settings-store");
    _settingsStore = mod.useSettingsStore;
  }
  return _settingsStore;
}

// ========== Helper ==========

async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const store = await getSettingsStore();
  const { apiKey, clientId } = store.getState();
  const baseUrl = "/api/getnote";
  const res = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: {
      ...(init?.headers ?? {}),
      "Content-Type": "application/json",
      ...(apiKey ? { "X-Api-Key": apiKey } : {}),
      ...(clientId ? { "X-Client-ID": clientId } : {}),
    },
  });
  const body = await res.json();
  if (!body.success) {
    throw new Error(body.error?.message ?? "请求失败");
  }
  return body.data;
}

// ========== Note Hooks ==========

export function useNotes(cursor?: string) {
  return useQuery({
    queryKey: queryKeys.notes.list(cursor),
    queryFn: () => apiFetch<NoteListResponse>(`/notes${cursor ? `?cursor=${cursor}` : ""}`),
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

export function useNoteDetail(noteId: string) {
  return useQuery({
    queryKey: queryKeys.notes.detail(noteId),
    queryFn: async () => {
      const result = await apiFetch<{ note: NoteDetail }>(`/notes/${noteId}`);
      return result.note;
    },
    enabled: !!noteId,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

export function useSaveNote() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: SaveNoteRequest) =>
      apiFetch<SaveNoteResponse>("/notes", {
        method: "POST",
        body: JSON.stringify(data),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.notes.all });
      qc.invalidateQueries({ queryKey: queryKeys.knowledge.all });
    },
  });
}

export function useTaskProgress(taskId: string) {
  return useQuery({
    queryKey: queryKeys.task(taskId),
    queryFn: () =>
      apiFetch<TaskProgress>("/task", {
        method: "POST",
        body: JSON.stringify({ task_id: taskId }),
      }),
    enabled: !!taskId,
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      if (status === "success" || status === "failed") return false;
      return 5000;
    },
    retry: 1,
  });
}

// ========== Knowledge Base Hooks ==========

export function useKnowledgeBases(page = 1) {
  return useQuery({
    queryKey: queryKeys.knowledge.list(page),
    queryFn: () => apiFetch<KnowledgeListResponse>(`/knowledge?page=${page}`),
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

export function useCreateKnowledgeBase() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ name, description }: { name: string; description?: string }) =>
      apiFetch<{ topic_id: string }>("/knowledge", {
        method: "POST",
        body: JSON.stringify({ name, description }),
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.knowledge.all });
    },
  });
}

export function useKnowledgeNotes(topicId: string, page = 1) {
  return useQuery({
    queryKey: queryKeys.knowledge.notes(topicId, page),
    queryFn: () => apiFetch<KnowledgeNotesResponse>(`/knowledge/${topicId}?page=${page}`),
    enabled: !!topicId,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

// ========== Recall Hooks ==========

export function useGlobalRecall(query: string) {
  return useQuery({
    queryKey: queryKeys.recall.global(query),
    queryFn: () =>
      apiFetch<RecallResponse>("/recall", {
        method: "POST",
        body: JSON.stringify({ query, top_k: 5 }),
      }),
    enabled: query.length > 0,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

export function useKnowledgeRecall(topicId: string, query: string) {
  return useQuery({
    queryKey: queryKeys.recall.knowledge(topicId, query),
    queryFn: () =>
      apiFetch<RecallResponse>("/recall", {
        method: "POST",
        body: JSON.stringify({ query, top_k: 5, topic_id: topicId }),
      }),
    enabled: !!topicId && query.length > 0,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
}

// ========== Subscription Hooks ==========

export function useSubscriptions() {
  return useQuery({
    queryKey: queryKeys.subscriptions,
    queryFn: () => subscriptionStore.getSubscriptions(),
    staleTime: 0,
  });
}

export function useSubscribe() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (sub: Subscription) => {
      subscriptionStore.saveSubscription(sub);
      return sub;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.subscriptions });
    },
  });
}

export function useUnsubscribe() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (xyzrankId: string) => {
      subscriptionStore.removeSubscription(xyzrankId);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: queryKeys.subscriptions });
    },
  });
}

// ========== Podcast Rankings Hooks ==========

export function useRankings(offset = 0, limit = 50) {
  return useQuery({
    queryKey: queryKeys.rankings.page(offset, limit),
    queryFn: async () => {
      const res = await fetch(`/api/podcasts/rankings?offset=${offset}&limit=${limit}`);
      const body = await res.json();
      if (!body.success) throw new Error(body.error?.message);
      return body.data;
    },
    staleTime: 60 * 60 * 1000,
    retry: 1,
  });
}

// ========== RSS Feed Hooks ==========

export function useRssFeed() {
  return useMutation({
    mutationFn: async (url: string) => {
      const res = await fetch("/api/podcasts/feed", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url }),
      });
      const body = await res.json();
      if (!body.success) throw new Error(body.error?.message);
      return body.data;
    },
  });
}
