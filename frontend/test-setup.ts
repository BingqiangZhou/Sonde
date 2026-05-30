import { JSDOM } from "jsdom";

// Ensure localStorage is available globally for jsdom environment
if (typeof globalThis.localStorage === "undefined") {
  const dom = new JSDOM("<!DOCTYPE html>", { url: "http://localhost" });
  globalThis.localStorage = dom.window.localStorage;
}
