# Build stage
FROM mcr.microsoft.com/dotnet/nightly/sdk:10.0-preview AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["GameStore.Api/GameStore.Api.csproj", "GameStore.Api/"]
RUN dotnet restore "GameStore.Api/GameStore.Api.csproj"

# Copy everything else and build
COPY GameStore.Api/ GameStore.Api/
WORKDIR "/src/GameStore.Api"
RUN dotnet build "GameStore.Api.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "GameStore.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/nightly/aspnet:10.0-preview AS final
WORKDIR /app

# Use existing non-root user from base image
USER $APP_UID

EXPOSE 8080

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "GameStore.Api.dll"]
