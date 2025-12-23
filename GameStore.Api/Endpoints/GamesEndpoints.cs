using GameStore.Api.Dtos;

namespace GameStore.Api.Endpoints;

public static class GamesEndpoints
{
    private static readonly List<GameDto> games = [
        new(1, "Street Fighter II", "Fighting", "Classic arcade fighting game", new DateOnly(1991, 2, 1)),
        new(2, "The Legend of Zelda", "Adventure", "Epic fantasy adventure", new DateOnly(1986, 2, 21)),
        new(3, "Minecraft", "Sandbox", "Block-based creative game", new DateOnly(2011, 11, 18))
    ];

    public static RouteGroupBuilder MapGamesEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/games")
                       .WithParameterValidation();

        group.MapGet("/", () => games);

        group.MapGet("/{id}", (int id) =>
        {
            GameDto? game = games.Find(game => game.Id == id);
            return game is null ? Results.NotFound() : Results.Ok(game);
        })
        .WithName("GetGame");

        group.MapPost("/", (CreateGameDto newGame) =>
        {
            GameDto game = new(
                games.Count + 1,
                newGame.Name,
                newGame.Genre,
                newGame.Description,
                newGame.ReleaseDate
            );

            games.Add(game);

            return Results.CreatedAtRoute("GetGame", new { id = game.Id }, game);
        });

        group.MapPut("/{id}", (int id, CreateGameDto updatedGame) =>
        {
            var index = games.FindIndex(game => game.Id == id);

            if (index == -1)
            {
                return Results.NotFound();
            }

            games[index] = new GameDto(
                id,
                updatedGame.Name,
                updatedGame.Genre,
                updatedGame.Description,
                updatedGame.ReleaseDate
            );

            return Results.NoContent();
        });

        group.MapDelete("/{id}", (int id) =>
        {
            var index = games.FindIndex(game => game.Id == id);

            if (index == -1)
            {
                return Results.NotFound();
            }

            games.RemoveAt(index);

            return Results.NoContent();
        });

        return group;
    }
}
