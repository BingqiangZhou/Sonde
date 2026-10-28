import { route, index } from '@react-router/dev/routes';

export default [
  index('routes/home.tsx'),
  route('daily', 'routes/daily.tsx'),
  route('daily/:key', 'routes/daily-detail.tsx'),
  route('weekly', 'routes/weekly.tsx'),
  route('weekly/:key', 'routes/weekly-detail.tsx'),
  route('monthly', 'routes/monthly.tsx'),
  route('monthly/:key', 'routes/monthly-detail.tsx'),
  route('all', 'routes/all.tsx'),
  route('archive', 'routes/archive.tsx'),
  route('favorites', 'routes/favorites.tsx'),
  route('changelog', 'routes/changelog.tsx'),
  route('me', 'routes/me.tsx'),
  route('episodes/:id', 'routes/episode-detail.tsx'),
  route('about', 'routes/about.tsx'),
];
