# OPTIMIZATIONS.md

### 1) Optimization Summary

* **Health Summary**: The codebase is well-structured using Clean Architecture, but currently suffers from **sequential I/O bottlenecks** in the backend and **UI flickering** during pagination in the frontend. The recommendation engine is functional but performs redundant calculations on every scored movie.
* **Top 3 Improvements**:
    1. **Parallelize Backend I/O with Concurrency Control**: Use `asyncio.gather` with `asyncio.Semaphore(10)` for TMDB API limits.
    2. **Flutter Image Caching**: Implement `cached_network_image` to prevent redundant network loads during card swipes.
    3. **Pre-fetch Movie Deck**: Implement a buffer-loading strategy in Flutter to avoid showing the loading skeleton between decks.
* **Biggest Risk**: As the movie database grows, the sequential synchronization and "fetch-all-unseen" recommendation pattern will lead to significant latency spikes and potential timeouts.

---

### 2) Findings (Prioritized)

#### **Sequential Category & Page Sync**
* **Category**: Network / Concurrency
* **Severity**: High
* **Impact**: Latency / Throughput
* **Evidence**: `MovieSyncService.sync_movies` (line 39) and `_sync_category` (line 58).
* **Why it’s inefficient**: Categories and pages are fetched one after another. If each category takes 1s and you have 5 categories, it takes 5s minimum.
* **Recommended fix**: Use `asyncio.gather(*[self._sync_category(cat, pages) for cat in categories])` and similar for pages. **Crucial**: Wrap calls with `asyncio.Semaphore(10)` to respect TMDB rate limits.
* **Tradeoffs / Risks**: Increased pressure on TMDB API (rate limits) and Supabase connection pool.
* **Expected impact estimate**: 3x - 5x faster synchronization.
* **Removal Safety**: Safe
* **Reuse Scope**: `MovieSyncService`

#### **Redundant Datetime Calculations in Recommendation Engine**
* **Category**: CPU / Algorithm
* **Severity**: Medium
* **Impact**: Latency
* **Evidence**: `MovieScorer._freshness_score` (line 186) calls `datetime.now()` inside a loop for every movie.
* **Why it’s inefficient**: `datetime.now()` is relatively expensive and produces the same result for all movies in a single recommendation request.
* **Recommended fix**: Calculate `now = datetime.now()` once in `get_recommendations` and pass it down or store it in the `Scorer`.
* **Tradeoffs / Risks**: None.
* **Expected impact estimate**: Small (5-10% CPU reduction in scoring hot path).
* **Removal Safety**: Safe
* **Reuse Scope**: `RecommendationService`

#### **Undeclared Foreign Key Bottleneck in Swipes**
* **Category**: DB / Reliability
* **Severity**: Medium
* **Impact**: Throughput / Reliability
* **Evidence**: `MovieRepositoryImpl.swipe` (line 114) performs a JIT import of movies inside a recursive error handler.
* **Why it’s inefficient**: If multiple movies are missing, each swipe triggers a sequential API call + DB insert + original swipe retry.
* **Recommended fix**: Ensure `MovieSyncService` keeps the DB warmed. In the UI, validate movie presence before swiping or batch the presence check.
* **Tradeoffs / Risks**: Requires more proactive synchronization.
* **Expected impact estimate**: Prevents 1-2s lag spikes on first-time swipes.
* **Removal Safety**: Needs Verification
* **Reuse Scope**: `MovieRepositoryImpl`

#### **Missing Image Caching in Flutter**
* **Category**: Frontend / Network / UX
* **Severity**: High
* **Impact**: Data Usage / UI Fluidity
* **Evidence**: `MovieCard` (assumed based on `pubspec.yaml` missing `cached_network_image`).
* **Why it’s inefficient**: Cards are swiped frequently. Without caching, the same movie posters are re-downloaded if they reappear (e.g., after a reload or deck refresh), causing lag and high data usage.
* **Recommended fix**: Add `cached_network_image` to `pubspec.yaml` and replace `Image.network` with `CachedNetworkImage`.
* **Tradeoffs / Risks**: Minimal storage overhead for local cache.
* **Expected impact estimate**: 80-90% reduction in image-related network traffic.
* **Removal Safety**: Safe
* **Reuse Scope**: `MovieCard` / `MovieDetailPage`

#### **Flickering Deck Transition (Pagination)**
* **Category**: Frontend / UX
* **Severity**: Medium
* **Impact**: UX Latency
* **Evidence**: `SwipePage.onEnd` (line 151) triggers `LoadMoviesEvent` which instantly emits `MoviesLoading`.
* **Why it’s inefficient**: The user sees a "No more movies" screen and then a loading skeleton every time the deck finishes.
* **Recommended fix**: Implement "Infinite Scroll" logic. Trigger `LoadMoviesEvent` when `currentIndex` reaches `movies.length - 5`. Use a "LoadingMore" state that preserves existing movies in the list.
* **Tradeoffs / Risks**: Increased complexity in Bloc state (appending lists).
* **Expected impact estimate**: 100% reduction in perceived latency between decks.
* **Removal Safety**: Safe
* **Reuse Scope**: `SwipePage` / `MoviesBloc`

---

### 3) Quick Wins (Do First)

1. **Implement `asyncio.Semaphore(10)`** for all parallel TMDB sync tasks.
2. **Add `cached_network_image`** to Flutter dependencies.
3. **Move `datetime.now()` out of the loop** in `MovieScorer`.

---

### 4) Deeper Optimizations (Do Next)

* **Server-Side Scoring (Supabase RPC)**: Move the scoring logic into a PostgreSQL function using PL/pgSQL to avoid fetching 300+ movies to the Python app.
* **Vector Indexing**: Ensure `pgvector` has an `HNSW` or `IVFFlat` index for the recommendation engine as the dataset scales beyond 5,000 movies.

---

### 5) Validation Plan

* **Backend Latency**: Use `timeit` or `cProfile` on `sync_movies` before/after parallelization.
* **Memory usage**: Monitor Python process resident set size (RSS) during `get_recommendations` with 1000+ movies.
* **Rebuild Profile**: Use Flutter DevTools "Performance" tab to profile `SwipePage` rebuilds during card swipes and pagination.

---

### 6) Optimized Code Snippet (Parallel Sync)

```python
# backend/app/services/movie_sync_service.py rewrite snippet
async def sync_movies(self, categories: List[str] = None, pages_per_category: int = 3) -> Dict:
    if categories is None:
        categories = ["popular", "now_playing", "upcoming", "top_rated", "trending"]
    
    # Run categories in parallel
    tasks = [self._sync_category(category, pages_per_category) for category in categories]
    results = await asyncio.gather(*tasks)
    
    # Aggregate stats...
    # (Merge results into stats dict)
```
