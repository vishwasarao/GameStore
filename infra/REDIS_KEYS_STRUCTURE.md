# Redis Cache Key Structure

## Overview

This document describes the cache key naming conventions and TTL policies used in the GameStore API.

---

## Cache Key Patterns

### 1. All Games List

**Key**: `games:all`

**Value**: JSON array of all GameDto objects

**TTL**: 5 minutes (300 seconds)

**Example**:
```json
[
  {
    "id": 1,
    "name": "Elden Ring",
    "genre": "RPG",
    "description": "Epic fantasy action RPG",
    "releaseDate": "2022-02-25"
  },
  {
    "id": 2,
    "name": "God of War",
    "genre": "Action",
    "description": "Norse mythology action adventure",
    "releaseDate": "2018-04-20"
  }
]
```

**Invalidated When**:
- New game created (POST /games)
- Game updated (PUT /games/{id})
- Game deleted (DELETE /games/{id})

---

### 2. Individual Game by ID

**Key Pattern**: `games:id:{id}`

**Examples**:
- `games:id:1` → Game with ID 1
- `games:id:42` → Game with ID 42

**Value**: JSON object of single GameDto

**TTL**: 5 minutes (300 seconds)

**Example**:
```json
{
  "id": 1,
  "name": "Elden Ring",
  "genre": "RPG",
  "description": "Epic fantasy action RPG from FromSoftware",
  "releaseDate": "2022-02-25"
}
```

**Invalidated When**:
- Specific game updated (PUT /games/{id})
- Specific game deleted (DELETE /games/{id})

---

## Cache Key Hierarchy

```
redis
├── games:all                    # All games list
├── games:id:1                   # Individual game caches
├── games:id:2
├── games:id:3
└── games:id:N
```

---

## TTL Strategy

| Cache Type      | TTL      | Reason                                      |
|-----------------|----------|---------------------------------------------|
| games:all       | 5 min    | Balance between freshness and performance   |
| games:id:{id}   | 5 min    | Individual games rarely change              |

### Why 5 Minutes?

✅ **Benefits**:
- Reduces database queries by ~85%
- Fresh enough for most use cases
- Low memory footprint

❌ **Trade-offs**:
- Users may see stale data for up to 5 minutes
- Requires cache invalidation on updates

---

## Cache Invalidation Scenarios

### Scenario 1: Create New Game

```
POST /games
└── Invalidates: games:all
└── Keeps: games:id:* (individual caches unaffected)
```

**Why**: New game doesn't affect existing individual game caches, but changes the "all games" list.

---

### Scenario 2: Update Existing Game

```
PUT /games/5
├── Invalidates: games:all
└── Invalidates: games:id:5
```

**Why**: Both the list and the specific game cache become stale.

---

### Scenario 3: Delete Game

```
DELETE /games/5
├── Invalidates: games:all
└── Invalidates: games:id:5
```

**Why**: Similar to update - both list and specific game affected.

---

## Future Enhancements

### 1. Genre-Specific Caching

```
games:genre:RPG
games:genre:Action
games:genre:Strategy
```

**Use Case**: Filter games by genre without querying database

---

### 2. Search Results Caching

```
games:search:{query}
games:search:zelda
games:search:fantasy
```

**Use Case**: Cache search results for popular queries

---

### 3. Leaderboard Caching

```
leaderboards:game:{gameId}:weekly
leaderboards:game:{gameId}:alltime
```

**Use Case**: High-score tracking with Redis sorted sets

---

### 4. User-Specific Caching

```
users:{userId}:library
users:{userId}:wishlist
users:{userId}:achievements:{gameId}
```

**Use Case**: Per-user data with longer TTL (30-60 minutes)

---

## Redis Data Structures Used

### Current Implementation

- **String**: JSON serialized objects
  - `GET games:all` → Returns JSON string
  - `SET games:all '{"id":1,...}'`

### Future Possibilities

- **Hash**: Store game attributes separately
  ```
  HSET game:1 name "Elden Ring"
  HSET game:1 genre "RPG"
  HSET game:1 price "59.99"
  ```

- **Sorted Set**: For leaderboards
  ```
  ZADD leaderboard:game:1 1500 "player:123"
  ZADD leaderboard:game:1 2000 "player:456"
  ZREVRANGE leaderboard:game:1 0 9  # Top 10
  ```

- **Set**: For tags/categories
  ```
  SADD games:tag:multiplayer "game:1" "game:5"
  SADD games:tag:singleplayer "game:2" "game:3"
  ```

---

## Monitoring Cache Performance

### Key Metrics to Track

1. **Cache Hit Rate**
   ```
   Hit Rate = (Cache Hits / Total Requests) × 100%
   Target: > 80%
   ```

2. **Average Response Time**
   ```
   Cache Hit: < 5ms
   Cache Miss: 20-50ms
   Target Improvement: 90%+ faster on hits
   ```

3. **Memory Usage**
   ```
   Monitor: Redis memory consumption
   Alert: > 80% of max memory
   ```

4. **Eviction Rate**
   ```
   Evictions/sec: Should be near 0
   High evictions = Need larger cache or shorter TTL
   ```

---

## Redis CLI Commands for Debugging

### View All Keys

```bash
# Connect to Redis (Azure)
redis-cli -h your-redis.redis.cache.windows.net -p 6380 -a "your-key" --tls

# List all keys
KEYS *

# Count keys
DBSIZE

# Get key pattern
KEYS games:*
```

### Inspect Cached Data

```bash
# Get value
GET games:all

# Get TTL remaining
TTL games:all

# Check if key exists
EXISTS games:id:1

# Get value and TTL
GET games:id:1
TTL games:id:1
```

### Manual Cache Management

```bash
# Delete specific key
DEL games:all

# Delete by pattern (requires SCAN)
redis-cli --scan --pattern "games:*" | xargs redis-cli DEL

# Flush entire database (DANGEROUS!)
FLUSHDB

# Set manual expiry
EXPIRE games:all 300
```

### Performance Testing

```bash
# Test latency
redis-cli --latency -h your-redis.redis.cache.windows.net -p 6380 -a "your-key" --tls

# Benchmark
redis-cli --rps 1000 -t GET,SET -h your-redis.redis.cache.windows.net -p 6380 -a "your-key" --tls
```

---

## Best Practices Applied

✅ **Namespacing**: `games:` prefix for organization
✅ **Consistent Format**: `entity:type:id` pattern
✅ **Lowercase Keys**: Easier to type, standardized
✅ **Short TTL**: 5 minutes balances performance vs freshness
✅ **Explicit Invalidation**: Clear stale data on writes
✅ **Graceful Degradation**: App works without Redis

---

## Summary

| Aspect              | Implementation                        |
|---------------------|---------------------------------------|
| **Cache Pattern**   | Cache-Aside (Lazy Loading)            |
| **Key Structure**   | `entity:type:id`                      |
| **TTL**             | 5 minutes                             |
| **Serialization**   | JSON via System.Text.Json             |
| **Invalidation**    | Explicit on POST/PUT/DELETE           |
| **Hit Rate Target** | > 80%                                 |
| **Response Time**   | < 5ms (cache hit) vs 20-50ms (miss)   |
