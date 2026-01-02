using StackExchange.Redis;

namespace GameStore.Api.Services;

/// <summary>
/// Redis-based rate limiter using sliding window algorithm
/// Provides distributed rate limiting across multiple application instances
/// </summary>
public class RedisRateLimiterService : IRateLimiterService
{
    private readonly IConnectionMultiplexer _redis;
    private readonly IDatabase _database;
    private readonly ILogger<RedisRateLimiterService> _logger;
    private readonly int _defaultLimit;
    private readonly TimeSpan _defaultWindow;

    public RedisRateLimiterService(
        IConnectionMultiplexer redis,
        ILogger<RedisRateLimiterService> logger,
        IConfiguration configuration)
    {
        _redis = redis;
        _database = redis.GetDatabase();
        _logger = logger;
        
        // Read from configuration with defaults
        _defaultLimit = configuration.GetValue<int>("RateLimiting:RequestsPerWindow", 100);
        _defaultWindow = TimeSpan.FromSeconds(
            configuration.GetValue<int>("RateLimiting:WindowInSeconds", 60)
        );
    }

    public async Task<RateLimitResult> CheckRateLimitAsync(string clientIdentifier, string? endpoint = null)
    {
        try
        {
            var key = BuildRateLimitKey(clientIdentifier, endpoint);
            var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var windowStart = now - (long)_defaultWindow.TotalSeconds;

            // Remove old entries outside the sliding window
            await _database.SortedSetRemoveRangeByScoreAsync(key, 0, windowStart);

            // Count requests in current window
            var requestCount = await _database.SortedSetLengthAsync(key);

            if (requestCount >= _defaultLimit)
            {
                // Rate limit exceeded
                var oldestEntry = await _database.SortedSetRangeByScoreAsync(key, 0, double.PositiveInfinity, Exclude.None, Order.Ascending, 0, 1);
                var retryAfter = oldestEntry.Length > 0
                    ? TimeSpan.FromSeconds((double)oldestEntry[0] + _defaultWindow.TotalSeconds - now)
                    : _defaultWindow;

                _logger.LogWarning(
                    "Rate limit exceeded for {Client} on {Endpoint}. Count: {Count}/{Limit}",
                    clientIdentifier, endpoint ?? "global", requestCount, _defaultLimit
                );

                return new RateLimitResult
                {
                    IsAllowed = false,
                    RequestsRemaining = 0,
                    TotalRequests = (int)requestCount,
                    LimitPerWindow = _defaultLimit,
                    WindowDuration = _defaultWindow,
                    RetryAfter = retryAfter > TimeSpan.Zero ? retryAfter : TimeSpan.FromSeconds(1)
                };
            }

            // Add current request to the sorted set with timestamp as score
            await _database.SortedSetAddAsync(key, now, now);

            // Set expiration to window duration to auto-cleanup
            await _database.KeyExpireAsync(key, _defaultWindow);

            var remaining = _defaultLimit - (int)requestCount - 1;

            _logger.LogDebug(
                "Rate limit check passed for {Client} on {Endpoint}. Remaining: {Remaining}/{Limit}",
                clientIdentifier, endpoint ?? "global", remaining, _defaultLimit
            );

            return new RateLimitResult
            {
                IsAllowed = true,
                RequestsRemaining = remaining,
                TotalRequests = (int)requestCount + 1,
                LimitPerWindow = _defaultLimit,
                WindowDuration = _defaultWindow,
                RetryAfter = null
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking rate limit for {Client}", clientIdentifier);
            
            // Fail open - allow request if Redis is down
            return new RateLimitResult
            {
                IsAllowed = true,
                RequestsRemaining = _defaultLimit,
                TotalRequests = 0,
                LimitPerWindow = _defaultLimit,
                WindowDuration = _defaultWindow,
                RetryAfter = null
            };
        }
    }

    private static string BuildRateLimitKey(string clientIdentifier, string? endpoint)
    {
        var sanitizedClient = clientIdentifier.Replace(":", "_").Replace(" ", "_");
        return endpoint is null
            ? $"ratelimit:{sanitizedClient}"
            : $"ratelimit:{sanitizedClient}:{endpoint}";
    }
}
