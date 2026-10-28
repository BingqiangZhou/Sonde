"""iTunes/Apple Podcasts 发现服务（Phase E；对齐 ts-era itunes.ts 语义）。

- 搜索：多国商店并发查询，按 feedUrl 合并去重，标注命中商店；
- 热门榜：Apple marketingtools 榜单 JSON 取 id 顺序，再 lookup 批量换 feedUrl；
- 5 分钟内存缓存（官方接口限频约 20 次/分钟）；
- 出站定制：ITUNES_DNS（aiodns 自定义解析器）或 ITUNES_PROXY_URL（HTTP 代理，优先）。
免费官方接口，不走 receipts。
"""

from __future__ import annotations

import asyncio
import logging
import time

import aiohttp

from app.core.config import get_settings
from app.core.exceptions import ValidationError


logger = logging.getLogger(__name__)

ITUNES_SEARCH_URL = "https://itunes.apple.com/search"
ITUNES_LOOKUP_URL = "https://itunes.apple.com/lookup"
CHARTS_URL = (
    "https://rss.marketingtools.apple.com/api/v2/{country}/podcasts/top/{limit}/podcasts.json"
)
CACHE_TTL_SECONDS = 300
REQUEST_TIMEOUT = 10.0


class DiscoveredPodcast:
    __slots__ = (
        "collection_id", "name", "author", "genre", "track_count",
        "artwork_url", "feed_url", "apple_url", "rank", "stores",
    )

    def __init__(self, **kw):
        for k in self.__slots__:
            setattr(self, k, kw.get(k))

    def to_dict(self, subscribed: bool = False) -> dict:
        return {
            "collectionId": self.collection_id,
            "name": self.name,
            "author": self.author,
            "genre": self.genre,
            "trackCount": self.track_count,
            "artworkUrl": self.artwork_url,
            "feedUrl": self.feed_url,
            "appleUrl": self.apple_url,
            "rank": self.rank,
            "stores": self.stores,
            "subscribed": subscribed,
        }


class DiscoverService:
    """搜索 + 热门榜（缓存 + 出站定制）。"""

    _cache: dict[str, tuple[float, object]] = {}
    _cache_lock = asyncio.Lock()

    async def _session(self) -> aiohttp.ClientSession:
        settings = get_settings()
        connector_kwargs: dict = {"ttl_dns_cache": 300}
        if settings.ITUNES_PROXY_URL:
            connector = aiohttp.TCPConnector(**connector_kwargs)
        elif settings.ITUNES_DNS:
            # aiodns 4.x：AsyncResolver → DNSResolver
            from aiodns import DNSResolver

            connector = aiohttp.TCPConnector(
                resolver=DNSResolver(nameservers=[settings.ITUNES_DNS]),
                **connector_kwargs,
            )
        else:
            connector = aiohttp.TCPConnector(**connector_kwargs)
        return aiohttp.ClientSession(
            connector=connector,
            timeout=aiohttp.ClientTimeout(total=settings.ITUNES_TIMEOUT_SECONDS or REQUEST_TIMEOUT),
            headers={"User-Agent": "SondeBot/2.0 (+https://github.com/BingqiangZhou/Sonde)"},
        )

    async def _get_json(self, url: str, params: dict | None = None) -> dict:
        proxy = get_settings().ITUNES_PROXY_URL or None
        session = await self._session()
        try:
            async with session.get(url, params=params, proxy=proxy) as resp:
                if resp.status != 200:
                    body = (await resp.text())[:200]
                    raise ValidationError(f"iTunes API HTTP {resp.status}: {body}")
                return await resp.json(content_type=None)
        finally:
            await session.close()

    async def _cached(self, key: str, factory):
        async with self._cache_lock:
            hit = self._cache.get(key)
            if hit and hit[0] > time.monotonic():
                return hit[1]
        value = await factory()
        async with self._cache_lock:
            self._cache[key] = (time.monotonic() + CACHE_TTL_SECONDS, value)
        return value

    # ── 搜索 ──

    async def search(self, term: str, *, limit: int = 20) -> dict:
        term = (term or "").strip()
        if len(term) < 2:
            raise ValidationError("Search term too short")
        countries = [c.strip().upper() for c in get_settings().ITUNES_COUNTRIES.split(",") if c.strip()]

        async def factory():
            tasks = [self._search_one(term, c, limit) for c in countries]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            merged: dict[str, DiscoveredPodcast] = {}
            failed: list[str] = []
            for country, outcome in zip(countries, results, strict=False):
                if isinstance(outcome, BaseException):
                    failed.append(country)
                    logger.warning("iTunes search failed for country %s: %s", country, outcome)
                    continue
                for item in outcome:
                    feed = (item.feed_url or "").lower()
                    key = feed or f"id:{item.collection_id}"
                    existing = merged.get(key)
                    if existing is None:
                        merged[key] = item
                    elif country not in existing.stores:
                        existing.stores.append(country)
            ordered = sorted(
                merged.values(),
                key=lambda p: (p.rank is not None, -(p.rank or 999), -(p.track_count or 0)),
            )[:limit]
            return {"countries": countries, "failed": failed, "results": ordered}

        data = await self._cached(f"search:{term.lower()}:{limit}", factory)
        return data

    async def _search_one(self, term: str, country: str, limit: int) -> list[DiscoveredPodcast]:
        data = await self._get_json(
            ITUNES_SEARCH_URL,
            {"term": term, "media": "podcast", "entity": "podcast", "limit": str(limit), "country": country},
        )
        out = []
        for r in data.get("results", []):
            feed_url = r.get("feedUrl")
            out.append(
                DiscoveredPodcast(
                    collection_id=r.get("collectionId"),
                    name=r.get("collectionName") or r.get("trackName"),
                    author=r.get("artistName"),
                    genre=r.get("primaryGenreName"),
                    track_count=r.get("trackCount"),
                    artwork_url=(r.get("artworkUrl600") or r.get("artworkUrl100")),
                    feed_url=feed_url,
                    apple_url=r.get("collectionViewUrl") or r.get("trackViewUrl"),
                    rank=None,
                    stores=[country],
                )
            )
        return out

    # ── 热门榜 ──

    async def charts(self, country: str = "CN", *, limit: int = 50) -> dict:
        country = (country or "CN").strip().lower()
        if len(country) != 2 or not country.isalpha():
            raise ValidationError(f"Invalid country code: {country}")
        limit = max(1, min(limit, 100))

        async def factory():
            chart = await self._get_json(CHARTS_URL.format(country=country, limit=limit))
            entries = (chart.get("feed") or {}).get("results") or []
            ids = [str(e["id"]) for e in entries if e.get("id")][:limit]
            names = {str(e["id"]): e for e in entries}

            feed_by_id: dict[str, str] = {}
            if ids:
                lookup = await self._get_json(
                    ITUNES_LOOKUP_URL, {"id": ",".join(ids), "entity": "podcast"}
                )
                for r in lookup.get("results", []):
                    if r.get("wrapperType") == "track" or r.get("kind") == "podcast":
                        feed_by_id[str(r.get("collectionId", r.get("trackId")))] = r.get("feedUrl")

            def _genre_name(entry: dict) -> str | None:
                genres = entry.get("genres")
                if isinstance(genres, list) and genres:
                    first = genres[0]
                    if isinstance(first, dict):
                        return first.get("name")
                    return first if isinstance(first, str) else None
                if isinstance(genres, dict):
                    return genres.get("name")
                return None

            results = []
            for rank, id_ in enumerate(ids, start=1):
                entry = names.get(id_, {})
                results.append(
                    DiscoveredPodcast(
                        collection_id=int(id_) if id_.isdigit() else None,
                        name=entry.get("name"),
                        author=entry.get("artistName"),
                        genre=_genre_name(entry),
                        track_count=None,
                        artwork_url=entry.get("artworkUrl100") or entry.get("artworkUrl"),
                        feed_url=feed_by_id.get(id_),
                        apple_url=entry.get("url"),
                        rank=rank,
                        stores=[country],
                    )
                )
            return results

        results = await self._cached(f"charts:{country}:{limit}", factory)
        return {"country": country, "total": len(results), "results": results}

    @classmethod
    def clear_cache(cls) -> None:
        cls._cache.clear()
