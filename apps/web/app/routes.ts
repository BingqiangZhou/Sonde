import { route, index } from '@react-router/dev/routes';

export default [
  index('routes/home.tsx'),
  route('daily', 'routes/daily.tsx'),
  route('daily/:key', 'routes/daily-detail.tsx'),
  route('archive', 'routes/archive.tsx'),
  route('episodes/:id', 'routes/episode-detail.tsx'),
  route('about', 'routes/about.tsx'),
];
