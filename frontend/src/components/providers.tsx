import { Toaster } from 'sonner';
import { Sidebar } from '@/components/layout/sidebar';
import { SidebarProvider } from '@/components/layout/sidebar-context';
import { ThemeProvider } from '@/components/layout/theme-provider';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider>
      <SidebarProvider>
        <div className="flex h-screen overflow-hidden">
          <Sidebar />
          <main className="flex-1 overflow-y-auto">
            <div className="container mx-auto max-w-7xl px-4 pt-20 pb-6 lg:px-8 lg:pt-6">
              {children}
            </div>
          </main>
        </div>
      </SidebarProvider>
      <Toaster position="top-right" richColors />
    </ThemeProvider>
  );
}
