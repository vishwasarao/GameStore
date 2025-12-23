namespace GameStore.Api.Entities;

public class Game
{
    public int Id { get; set; }
    
    public required string Name { get; set; }
    
    public int GenreId { get; set; }
    
    public Genre? Genre { get; set; }
    
    public required string Description { get; set; }
    
    public DateOnly ReleaseDate { get; set; }
}
