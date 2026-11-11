import { index, route } from '@react-router/dev/routes';

export default [
  index('routes/home.tsx'),
  // 无限滚动的追加批资源路由(仅 loader)
  route('resources/episodes', 'routes/resources.episodes.ts'),
];
