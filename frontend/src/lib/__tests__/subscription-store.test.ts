import { describe, it, expect, beforeEach } from "vitest";
import {
  getSubscriptions,
  saveSubscription,
  removeSubscription,
  isSubscribed,
  clearSubscriptions,
} from "@/lib/subscription-store";
import type { Subscription } from "@/types";

const STORAGE_KEY = "podcastinsight_subscriptions";

const mockSubscription: Subscription = {
  xyzrankId: "podcast-1",
  topicId: "topic-1",
  podcastName: "Test Podcast",
  rssUrl: "https://example.com/feed.xml",
  logoUrl: "https://example.com/logo.png",
  category: "Tech",
};

function loadStore(): Record<string, Subscription> {
  const raw = localStorage.getItem(STORAGE_KEY);
  return raw ? JSON.parse(raw) : {};
}

describe("subscription-store", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  describe("getSubscriptions", () => {
    it("returns empty object when no subscriptions exist", () => {
      expect(getSubscriptions()).toEqual({});
    });

    it("returns stored subscriptions", () => {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ "podcast-1": mockSubscription }));
      const result = getSubscriptions();
      expect(result["podcast-1"]).toEqual(mockSubscription);
    });

    it("returns empty object for corrupted data", () => {
      localStorage.setItem(STORAGE_KEY, "not-valid-json{{{");
      expect(getSubscriptions()).toEqual({});
    });
  });

  describe("saveSubscription", () => {
    it("saves a new subscription", () => {
      saveSubscription(mockSubscription);
      const stored = loadStore();
      expect(stored["podcast-1"]).toEqual(mockSubscription);
    });

    it("overwrites existing subscription", () => {
      saveSubscription(mockSubscription);
      const updated: Subscription = { ...mockSubscription, podcastName: "Updated" };
      saveSubscription(updated);
      const stored = loadStore();
      expect(stored["podcast-1"].podcastName).toBe("Updated");
    });
  });

  describe("removeSubscription", () => {
    it("removes an existing subscription", () => {
      saveSubscription(mockSubscription);
      removeSubscription("podcast-1");
      expect(loadStore()["podcast-1"]).toBeUndefined();
    });

    it("does nothing for non-existent subscription", () => {
      removeSubscription("non-existent");
      expect(loadStore()).toEqual({});
    });
  });

  describe("isSubscribed", () => {
    it("returns true when subscribed", () => {
      saveSubscription(mockSubscription);
      expect(isSubscribed("podcast-1")).toBe(true);
    });

    it("returns false when not subscribed", () => {
      expect(isSubscribed("podcast-1")).toBe(false);
    });
  });

  describe("clearSubscriptions", () => {
    it("clears all subscriptions", () => {
      saveSubscription(mockSubscription);
      clearSubscriptions();
      expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
    });
  });
});
