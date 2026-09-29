import { route, index } from '@react-router/dev/routes';

export default [
  index('routes/home.tsx'),
  route('daily', 'routes/daily.tsx'),
  route('daily/:key', 'routes/daily-detail.tsx'),
  route('archive', 'routes/archive.tsx'),
  route('episodes/:id', 'routes/episode-detail.tsx'),
  route('about', 'routes/about.tsx'),
  route('admin/login', 'routes/admin/login.tsx'),
  route('admin', 'routes/admin/layout.tsx', [
    index('routes/admin/dashboard.tsx'),
    route('sources', 'routes/admin/sources.tsx'),
    route('episodes', 'routes/admin/episodes.tsx'),
    route('reports', 'routes/admin/reports.tsx'),
    route('costs', 'routes/admin/costs.tsx'),
  ]),
];
