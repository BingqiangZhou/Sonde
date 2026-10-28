import type { LoaderFunction } from 'react-router';
import { redirect } from 'react-router';

/** 「全部精选」已并入「全部动态」（/all）。 */
export const loader: LoaderFunction = () => redirect('/all');
