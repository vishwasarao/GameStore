namespace GameStore.Api.Services;

/// <summary>
/// No-op rate limiter for local development or when Redis is not configured
/// Always allows requests through without any limiting
/// </summary>
public class NoOpRateLimiterService : IRateLimiterService
{
    public Task<RateLimitResult> CheckRateLimitAsync(string clientIdentifier, string? endpoint = null)
    {
        return Task.FromResult(new RateLimitResult
        {
            IsAllowed = true,
            RequestsRemaining = int.MaxValue,
            TotalRequests = 0,
            LimitPerWindow = int.MaxValue,
            WindowDuration = TimeSpan.FromMinutes(1),
            RetryAfter = null
        });
    }
}
