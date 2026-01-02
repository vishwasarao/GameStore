# Rate Limiting with Redis

## What is Rate Limiting?

**Rate limiting** controls how many requests a client can make to your API within a time window. It prevents abuse, ensures fair usage, and protects your infrastructure.

---

## Why Do You Need It?

### ✅ **Protection**
- **DDoS Attacks**: Prevent attackers from overwhelming your servers
- **Brute Force**: Stop password guessing attempts
- **Scraping**: Block automated data harvesting
- **Resource Exhaustion**: Protect database and compute resources

### 💰 **Cost Control**
- Prevent unexpected Azure bills from abuse
- Limit free-tier usage before implementing paid plans
- Control database DTU/vCore consumption

### 🤝 **Fair Usage**
- Ensure all users get equal access
- Prevent one user from degrading service for others
- Enforce API tier limits (free vs premium)

### 📊 **Observability**
- Track usage patterns per client
- Identify suspicious behavior
- Plan capacity based on real usage

---

## Why Redis for Rate Limiting?

| Feature | Redis | Database | In-Memory |
|---------|-------|----------|-----------|
| **Speed** | ⚡ Sub-ms | 🐢 10-50ms | ⚡ Sub-ms |
| **Distributed** | ✅ Yes | ✅ Yes | ❌ No |
| **Auto-cleanup** | ✅ TTL | ❌ Manual | ✅ Built-in |
| **Atomic ops** | ✅ INCR | ⚠️ Locks | ⚠️ Thread-safe |
| **Scalability** | ✅ High | ⚠️ Medium | ❌ Single node |

**Redis wins because:**
- ⚡ Atomic operations (no race conditions)
- 🌐 Works across multiple API instances
- 🕐 Built-in TTL for automatic cleanup
- 🚀 Handles millions of requests/second

---

## Implementation

### Algorithm: Sliding Window

Uses **Redis Sorted Sets** to track request timestamps:

```
Time: ----|----|----|----|----|----|----|----|---->
         50s  51s  52s  53s  54s  55s  56s  57s  (now)
                          ↑__________________|
                          Sliding 60s window
```

**How it works:**
1. Remove requests older than window (60s ago)
2. Count remaining requests in window
3. If count ≥ limit → Reject (429 Too Many Requests)
4. If count < limit → Allow + add current timestamp
5. Auto-expire key after window duration

**Advantages:**
- ✅ More accurate than fixed windows
- ✅ No sudden burst at window boundary
- ✅ Memory efficient with auto-cleanup

---

## Configuration

### appsettings.json (Production)
```json
{
  "RateLimiting": {
    "RequestsPerWindow": 100,
    "WindowInSeconds": 60
  }
}
```
**Limit: 100 requests per minute**

### appsettings.Development.json (Dev)
```json
{
  "RateLimiting": {
    "RequestsPerWindow": 1000,
    "WindowInSeconds": 60
  }
}
```
**Limit: 1000 requests per minute (more lenient for testing)**

---

## Rate Limit Tiers

Recommended limits based on use case:

| Tier | Requests/Min | Requests/Hour | Use Case |
|------|--------------|---------------|----------|
| **Strict** | 30 | 1,800 | Public endpoints, unauthenticated |
| **Standard** | 100 | 6,000 | Authenticated users, free tier |
| **Premium** | 500 | 30,000 | Paid users, higher SLA |
| **Internal** | 1000+ | 60,000+ | Internal services, dev/test |

### Example Configuration:

```json
// Strict (public API)
{
  "RateLimiting": {
    "RequestsPerWindow": 30,
    "WindowInSeconds": 60
  }
}

// Premium (paid users)
{
  "RateLimiting": {
    "RequestsPerWindow": 500,
    "WindowInSeconds": 60
  }
}
```

---

## Testing Rate Limiting

### 1. Manual Testing with cURL

```bash
# Test normal usage (should succeed)
for i in {1..10}; do
  curl -X GET http://localhost:5000/games
  echo "Request $i"
done

# Test exceeding limit (100 requests)
for i in {1..120}; do
  curl -X GET http://localhost:5000/games -w "\nStatus: %{http_code}\n"
  sleep 0.1
done
```

### 2. HTTP File Testing

Create `test_rate_limiting.http`:

```http
### Test 1: Normal request (should pass)
GET http://localhost:5000/games
Accept: application/json

###

### Test 2: Check rate limit headers
GET http://localhost:5000/games
Accept: application/json

# Look for these response headers:
# X-RateLimit-Limit: 100
# X-RateLimit-Remaining: 99
# X-RateLimit-Reset: 1735401234

###

### Test 3: Exceed limit (run this 101+ times)
GET http://localhost:5000/games
Accept: application/json

# After 100 requests, you should get:
# HTTP/1.1 429 Too Many Requests
# Retry-After: 42
```

### 3. Automated Load Testing

```bash
# Install Apache Bench
brew install httpd

# Send 200 requests, 10 concurrent
ab -n 200 -c 10 http://localhost:5000/games

# Expected: ~100 success (200), ~100 rate limited (429)
```

### 4. Load Testing with `hey`

```bash
# Install hey
brew install hey

# Send 500 requests with 50 workers
hey -n 500 -c 50 http://localhost:5000/games

# Output will show:
# - 200 OK responses (allowed)
# - 429 Too Many Requests (rate limited)
```

---

## Response Examples

### ✅ Request Allowed (200 OK)

```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 73
X-RateLimit-Reset: 1735401294

[
  {
    "id": 1,
    "name": "Elden Ring",
    ...
  }
]
```

### ❌ Rate Limit Exceeded (429 Too Many Requests)

```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1735401294
Retry-After: 42

{
  "error": "Rate limit exceeded",
  "message": "Too many requests. Limit: 100 requests per 60 seconds.",
  "retryAfter": 42,
  "limit": 100,
  "windowSeconds": 60
}
```

---

## Response Headers Explained

| Header | Description | Example |
|--------|-------------|---------|
| `X-RateLimit-Limit` | Maximum requests allowed in window | `100` |
| `X-RateLimit-Remaining` | Requests left in current window | `73` |
| `X-RateLimit-Reset` | Unix timestamp when window resets | `1735401294` |
| `Retry-After` | Seconds to wait before retry (429 only) | `42` |

---

## Client Identifier Strategy

The middleware identifies clients by:

1. **IP Address** (default)
   - From `X-Forwarded-For` header (if behind proxy/load balancer)
   - From `X-Real-IP` header
   - From connection remote address

2. **User ID** (if authenticated)
   - Combines IP + User ID: `192.168.1.1:user123`
   - Allows per-user limits even on shared IPs

### Redis Keys Structure

```
ratelimit:{ip}                           # Global limit per IP
ratelimit:{ip}:GET:/games               # Per-endpoint limit
ratelimit:{ip}:{userId}                 # Authenticated user limit
```

**Example:**
```
ratelimit:192.168.1.100
ratelimit:192.168.1.100:GET:/games
ratelimit:192.168.1.100:user123
```

---

## Advanced Scenarios

### 1. Different Limits Per Endpoint

Modify middleware to use custom limits:

```csharp
// In appsettings.json
{
  "RateLimiting": {
    "Endpoints": {
      "GET:/games": { "RequestsPerWindow": 100, "WindowInSeconds": 60 },
      "POST:/games": { "RequestsPerWindow": 10, "WindowInSeconds": 60 },
      "DELETE:/games": { "RequestsPerWindow": 5, "WindowInSeconds": 60 }
    }
  }
}
```

### 2. User Tier-Based Limits

```csharp
// Check user's subscription tier
var limit = user.IsPremium ? 500 : 100;
```

### 3. Whitelist IPs (No Limits)

```csharp
// In middleware
var trustedIps = new[] { "10.0.0.0/8", "internal-service-ip" };
if (trustedIps.Contains(clientIp))
{
    await _next(context); // Skip rate limiting
    return;
}
```

### 4. Bypass Rate Limiting with API Key

```csharp
// Check for API key header
var apiKey = context.Request.Headers["X-API-Key"].FirstOrDefault();
if (IsValidApiKey(apiKey))
{
    // Use higher limit for API key users
    result = await rateLimiter.CheckRateLimitAsync(apiKey, endpoint);
}
```

---

## Monitoring Rate Limits

### Azure Application Insights Query

```kusto
requests
| where resultCode == 429
| summarize RateLimitedRequests = count() by client_IP, bin(timestamp, 1m)
| order by RateLimitedRequests desc
```

### Redis CLI Inspection

```bash
# Connect to Redis
redis-cli -h your-redis.redis.cache.windows.net -p 6380 -a "key" --tls

# View all rate limit keys
KEYS ratelimit:*

# Inspect specific client
ZRANGE ratelimit:192.168.1.100 0 -1 WITHSCORES

# Count requests in window
ZCARD ratelimit:192.168.1.100

# Check TTL
TTL ratelimit:192.168.1.100

# Manually clear a client's limit (emergency)
DEL ratelimit:192.168.1.100
```

---

## Performance Impact

### Overhead per Request

- **Redis lookup**: ~1-2ms
- **Network latency**: ~0.5ms (same region)
- **Serialization**: ~0.1ms
- **Total**: ~2-3ms per request

### Throughput

- **Single Redis instance**: 100,000+ req/s
- **Clustered Redis**: 1,000,000+ req/s

**Conclusion**: Negligible performance impact with massive protection benefits.

---

## Graceful Degradation

If Redis is unavailable:
- ✅ **Fail Open**: Requests are allowed (no rate limiting)
- ✅ **No Crashes**: App continues to function
- ⚠️ **Logged**: Error logged for monitoring

```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Redis unavailable - allowing request");
    return new RateLimitResult { IsAllowed = true, ... };
}
```

---

## Best Practices

1. ✅ **Start Conservative**: 100 req/min, adjust based on usage
2. ✅ **Different Limits**: Write endpoints < Read endpoints
3. ✅ **Monitor 429s**: Alert on spike in rate limited requests
4. ✅ **Communicate Limits**: Document in API docs
5. ✅ **Return Clear Errors**: Include `Retry-After` header
6. ✅ **Use Sliding Window**: More accurate than fixed window
7. ✅ **Test Under Load**: Verify limits work correctly
8. ✅ **Whitelist Internal**: Exclude health checks, internal services

---

## When NOT to Use Rate Limiting

❌ **Internal services only**: No public exposure
❌ **Single tenant**: Known, trusted users
❌ **Already using API Gateway**: Azure API Management, AWS API Gateway handle it

---

## Cost Analysis

| Without Rate Limiting | With Rate Limiting |
|----------------------|-------------------|
| Vulnerable to DDoS | ✅ Protected |
| Unpredictable costs | ✅ Controlled costs |
| Database overload | ✅ Stable performance |
| Poor UX under load | ✅ Predictable behavior |

**Redis Cost**: ~$17-110/month
**Potential Savings**: $100s-$1000s in prevented abuse

**ROI**: Rate limiting pays for itself in the first attack attempt! 💰

---

## Summary

✅ **Implemented:**
- Redis-based sliding window rate limiter
- Per-IP and per-endpoint limits
- Standard HTTP 429 responses with headers
- Graceful fallback when Redis unavailable
- Configurable limits via appsettings.json

🎯 **Benefits:**
- Prevents DDoS and abuse
- Controls costs
- Protects database from overload
- Fair usage across users
- Production-ready with logging

🚀 **Recommended Settings:**
- **Dev**: 1000 req/min (testing)
- **Staging**: 100 req/min (realistic)
- **Production**: 30-100 req/min (strict)

---

## Resources

- [OWASP Rate Limiting](https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html)
- [Redis Rate Limiting Patterns](https://redis.io/docs/manual/patterns/rate-limiter/)
- [HTTP 429 Specification](https://tools.ietf.org/html/rfc6585#section-4)
