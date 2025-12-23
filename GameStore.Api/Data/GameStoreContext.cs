using GameStore.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace GameStore.Api.Data;

public class GameStoreContext : DbContext
{
    public GameStoreContext(DbContextOptions<GameStoreContext> options) : base(options)
    {
    }

    public DbSet<Game> Games => Set<Game>();
    public DbSet<Genre> Genres => Set<Genre>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Seed Genres
        modelBuilder.Entity<Genre>().HasData(
            new Genre { Id = 1, Name = "Action" },
            new Genre { Id = 2, Name = "Adventure" },
            new Genre { Id = 3, Name = "RPG" },
            new Genre { Id = 4, Name = "Strategy" },
            new Genre { Id = 5, Name = "Sports" },
            new Genre { Id = 6, Name = "Puzzle" },
            new Genre { Id = 7, Name = "Racing" }
        );

        // Seed Games
        modelBuilder.Entity<Game>().HasData(
            new Game
            {
                Id = 1,
                Name = "Elden Ring",
                GenreId = 3,
                Description = "Epic fantasy action RPG from FromSoftware",
                ReleaseDate = new DateOnly(2022, 2, 25)
            },
            new Game
            {
                Id = 2,
                Name = "God of War",
                GenreId = 1,
                Description = "Norse mythology action adventure",
                ReleaseDate = new DateOnly(2018, 4, 20)
            },
            new Game
            {
                Id = 3,
                Name = "The Legend of Zelda: Breath of the Wild",
                GenreId = 2,
                Description = "Open world adventure masterpiece",
                ReleaseDate = new DateOnly(2017, 3, 3)
            },
            new Game
            {
                Id = 4,
                Name = "Civilization VI",
                GenreId = 4,
                Description = "Turn-based strategy game",
                ReleaseDate = new DateOnly(2016, 10, 21)
            },
            new Game
            {
                Id = 5,
                Name = "FIFA 24",
                GenreId = 5,
                Description = "Football simulation",
                ReleaseDate = new DateOnly(2023, 9, 29)
            }
        );
    }
}
