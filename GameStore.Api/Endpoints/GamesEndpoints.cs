using GameStore.Api.Data;
using GameStore.Api.Dtos;
using GameStore.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace GameStore.Api.Endpoints;

public static class GamesEndpoints
{
    private const string GetAllGamesCacheKey = "games:all";
    private const string GetGameByIdCacheKeyPrefix = "games:id:";
    private static readonly TimeSpan CacheExpiration = TimeSpan.FromMinutes(5);

    public static RouteGroupBuilder MapGamesEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/games")
                       .WithParameterValidation();

        // GET /games - Get all games with caching
        group.MapGet("/", async (GameStoreContext db, ICacheService cache) =>
        {
            // Try to get from cache first
            var cachedGames = await cache.GetAsync<List<GameDto>>(GetAllGamesCacheKey);
            if (cachedGames is not null)
            {
                return Results.Ok(cachedGames);
            }

            // If not in cache, fetch from database
            var games = await db.Games
                .Include(g => g.Genre)
                .Select(g => new GameDto(
                    g.Id,
                    g.Name,
                    g.Genre!.Name,
                    g.Description,
                    g.ReleaseDate
                ))
                .ToListAsync();

            // Store in cache
            await cache.SetAsync(GetAllGamesCacheKey, games, CacheExpiration);

            return Results.Ok(games);
        });

        // GET /games/{id} - Get game by ID with caching
        group.MapGet("/{id}", async (int id, GameStoreContext db, ICacheService cache) =>
        {
            var cacheKey = $"{GetGameByIdCacheKeyPrefix}{id}";
            
            // Try to get from cache first
            var cachedGame = await cache.GetAsync<GameDto>(cacheKey);
            if (cachedGame is not null)
            {
                return Results.Ok(cachedGame);
            }

            // If not in cache, fetch from database
            var game = await db.Games
                .Include(g => g.Genre)
                .Where(g => g.Id == id)
                .Select(g => new GameDto(
                    g.Id,
                    g.Name,
                    g.Genre!.Name,
                    g.Description,
                    g.ReleaseDate
                ))
                .FirstOrDefaultAsync();

            if (game is null)
            {
                return Results.NotFound();
            }

            // Store in cache
            await cache.SetAsync(cacheKey, game, CacheExpiration);

            return Results.Ok(game);
        })
        .WithName("GetGame");

        // POST /games - Create new game and invalidate cache
        group.MapPost("/", async (CreateGameDto newGame, GameStoreContext db, ICacheService cache) =>
        {
            var genre = await db.Genres.FirstOrDefaultAsync(g => g.Name == newGame.Genre);
            if (genre is null)
            {
                return Results.BadRequest($"Genre '{newGame.Genre}' not found");
            }

            var game = new Entities.Game
            {
                Name = newGame.Name,
                GenreId = genre.Id,
                Description = newGame.Description,
                ReleaseDate = newGame.ReleaseDate
            };

            db.Games.Add(game);
            await db.SaveChangesAsync();

            // Invalidate cache
            await cache.RemoveAsync(GetAllGamesCacheKey);

            var gameDto = new GameDto(
                game.Id,
                game.Name,
                newGame.Genre,
                game.Description,
                game.ReleaseDate
            );

            return Results.CreatedAtRoute("GetGame", new { id = game.Id }, gameDto);
        });

        // PUT /games/{id} - Update game and invalidate cache
        group.MapPut("/{id}", async (int id, CreateGameDto updatedGame, GameStoreContext db, ICacheService cache) =>
        {
            var game = await db.Games.FindAsync(id);
            if (game is null)
            {
                return Results.NotFound();
            }

            var genre = await db.Genres.FirstOrDefaultAsync(g => g.Name == updatedGame.Genre);
            if (genre is null)
            {
                return Results.BadRequest($"Genre '{updatedGame.Genre}' not found");
            }

            game.Name = updatedGame.Name;
            game.GenreId = genre.Id;
            game.Description = updatedGame.Description;
            game.ReleaseDate = updatedGame.ReleaseDate;

            await db.SaveChangesAsync();

            // Invalidate cache
            await cache.RemoveAsync(GetAllGamesCacheKey);
            await cache.RemoveAsync($"{GetGameByIdCacheKeyPrefix}{id}");

            return Results.NoContent();
        });

        // DELETE /games/{id} - Delete game and invalidate cache
        group.MapDelete("/{id}", async (int id, GameStoreContext db, ICacheService cache) =>
        {
            var game = await db.Games.FindAsync(id);
            if (game is null)
            {
                return Results.NotFound();
            }

            db.Games.Remove(game);
            await db.SaveChangesAsync();

            // Invalidate cache
            await cache.RemoveAsync(GetAllGamesCacheKey);
            await cache.RemoveAsync($"{GetGameByIdCacheKeyPrefix}{id}");

            return Results.NoContent();
        });

        return group;
    }
}
