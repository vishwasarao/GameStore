namespace GameStore.Api.Services;

public interface IRateLimiterService
{
    /// <summary>
    /// Checks if the client has exceeded their rate limit
    /// </summary>
    /// <param name="clientIdentifier">Unique identifier for the client (IP, User ID, API Key, etc.)</param>
    /// <param name="endpoint">Optional endpoint identifier for per-endpoint limits</param>
    /// <returns>True if allowed, false if rate limit exceeded</returns>
    Task<RateLimitResult> CheckRateLimitAsync(string clientIdentifier, string? endpoint = null);
}

public record RateLimitResult
{
    public bool IsAllowed { get; init; }
    public int RequestsRemaining { get; init; }
    public int TotalRequests { get; init; }
    public int LimitPerWindow { get; init; }
    public TimeSpan WindowDuration { get; init; }
    public TimeSpan? RetryAfter { get; init; }
}
