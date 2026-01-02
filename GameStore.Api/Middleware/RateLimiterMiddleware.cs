using GameStore.Api.Services;
using System.Net;

namespace GameStore.Api.Middleware;

/// <summary>
/// Middleware for enforcing API rate limits
/// Returns 429 Too Many Requests when limits are exceeded
/// </summary>
public class RateLimiterMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RateLimiterMiddleware> _logger;

    public RateLimiterMiddleware(RequestDelegate next, ILogger<RateLimiterMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context, IRateLimiterService rateLimiter)
    {
        // Get client identifier (IP address + optional User ID from auth)
        var clientIdentifier = GetClientIdentifier(context);
        
        // Get endpoint for per-endpoint limits (optional)
        var endpoint = $"{context.Request.Method}:{context.Request.Path}";

        // Check rate limit
        var result = await rateLimiter.CheckRateLimitAsync(clientIdentifier, endpoint);

        // Add rate limit headers to response
        context.Response.Headers["X-RateLimit-Limit"] = result.LimitPerWindow.ToString();
        context.Response.Headers["X-RateLimit-Remaining"] = result.RequestsRemaining.ToString();
        context.Response.Headers["X-RateLimit-Reset"] = 
            DateTimeOffset.UtcNow.Add(result.WindowDuration).ToUnixTimeSeconds().ToString();

        if (!result.IsAllowed)
        {
            // Rate limit exceeded
            context.Response.StatusCode = (int)HttpStatusCode.TooManyRequests;
            context.Response.Headers["Retry-After"] = ((int)result.RetryAfter!.Value.TotalSeconds).ToString();
            
            await context.Response.WriteAsJsonAsync(new
            {
                error = "Rate limit exceeded",
                message = $"Too many requests. Limit: {result.LimitPerWindow} requests per {result.WindowDuration.TotalSeconds} seconds.",
                retryAfter = result.RetryAfter.Value.TotalSeconds,
                limit = result.LimitPerWindow,
                windowSeconds = (int)result.WindowDuration.TotalSeconds
            });

            _logger.LogWarning(
                "Rate limit exceeded for client {Client} on endpoint {Endpoint}",
                clientIdentifier, endpoint
            );

            return;
        }

        // Allow request to proceed
        await _next(context);
    }

    private static string GetClientIdentifier(HttpContext context)
    {
        // Try to get real IP from proxy headers (if behind load balancer)
        var ipAddress = context.Request.Headers["X-Forwarded-For"].FirstOrDefault()
                        ?? context.Request.Headers["X-Real-IP"].FirstOrDefault()
                        ?? context.Connection.RemoteIpAddress?.ToString()
                        ?? "unknown";

        // If authenticated, include user ID for per-user limits
        var userId = context.User?.Identity?.Name;
        
        return userId is not null ? $"{ipAddress}:{userId}" : ipAddress;
    }
}

/// <summary>
/// Extension method to easily add rate limiter middleware
/// </summary>
public static class RateLimiterMiddlewareExtensions
{
    public static IApplicationBuilder UseCustomRateLimiter(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<RateLimiterMiddleware>();
    }
}
