using GameStore.Api.Data;
using GameStore.Api.Endpoints;
using GameStore.Api.Middleware;
using GameStore.Api.Services;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Add DbContext
builder.Services.AddDbContext<GameStoreContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("GameStoreDB")));

// Add Redis and dependent services
var redisConnectionString = builder.Configuration.GetConnectionString("Redis");
if (!string.IsNullOrEmpty(redisConnectionString))
{
    builder.Services.AddSingleton<IConnectionMultiplexer>(sp =>
    {
        var configuration = ConfigurationOptions.Parse(redisConnectionString);
        configuration.AbortOnConnectFail = false; // Prevents app crash if Redis is unavailable
        return ConnectionMultiplexer.Connect(configuration);
    });
    
    builder.Services.AddScoped<ICacheService, RedisCacheService>();
    builder.Services.AddScoped<IRateLimiterService, RedisRateLimiterService>();
}
else
{
    // If Redis is not configured, use no-op services for local development
    builder.Services.AddScoped<ICacheService, NoOpCacheService>();
    builder.Services.AddScoped<IRateLimiterService, NoOpRateLimiterService>();
}

var app = builder.Build();

// Apply migrations and seed data on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<GameStoreContext>();
    db.Database.Migrate();
}

// Add rate limiting middleware (place before endpoint mapping)
app.UseCustomRateLimiter();

app.MapGamesEndpoints();

app.Run();
