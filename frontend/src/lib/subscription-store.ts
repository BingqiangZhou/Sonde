import type { Subscription, SubscriptionMap } from "@/types";

const STORAGE_KEY = "podcastinsight_subscriptions";

export function getSubscriptions(): SubscriptionMap {
  if (typeof window === "undefined") return {};
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

export function getSubscription(xyzrankId: string): Subscription | null {
  const map = getSubscriptions();
  return map[xyzrankId] ?? null;
}

export function saveSubscription(sub: Subscription): void {
  const map = getSubscriptions();
  map[sub.xyzrankId] = sub;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(map));
}

export function removeSubscription(xyzrankId: string): void {
  const map = getSubscriptions();
  delete map[xyzrankId];
  localStorage.setItem(STORAGE_KEY, JSON.stringify(map));
}

export function clearSubscriptions(): void {
  localStorage.removeItem(STORAGE_KEY);
}

export function isSubscribed(xyzrankId: string): boolean {
  return xyzrankId in getSubscriptions();
}
