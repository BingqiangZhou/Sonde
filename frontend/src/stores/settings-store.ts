import { create } from "zustand";
import { persist } from "zustand/middleware";

interface SettingsState {
  apiKey: string;
  clientId: string;
  setApiKey: (key: string) => void;
  setClientId: (id: string) => void;
  clear: () => void;
  isConfigured: () => boolean;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set, get) => ({
      apiKey: "",
      clientId: "",
      setApiKey: (key) => set({ apiKey: key }),
      setClientId: (id) => set({ clientId: id }),
      clear: () => set({ apiKey: "", clientId: "" }),
      isConfigured: () => !!(get().apiKey && get().clientId),
    }),
    { name: "podcastinsight_settings" }
  )
);
