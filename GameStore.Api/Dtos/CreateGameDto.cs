using System.ComponentModel.DataAnnotations;

namespace GameStore.Api.Dtos;

public record class CreateGameDto(
    [Required][StringLength(100)] string Name,
    [Required][StringLength(50)] string Genre,
    [Required][StringLength(500)] string Description,
    DateOnly ReleaseDate
);
