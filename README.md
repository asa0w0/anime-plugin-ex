# Anime Database Plugin Cache Management

This plugin uses a local cache to store anime and episode data for improved performance and to avoid rate-limiting from external APIs (Jikan/MyAnimeList and AniList).

## Rake Tasks

You can manage the cache using the following rake tasks from your Discourse root directory:

### Clear Cache
Completely removes all cached anime and episode data. The data will be re-fetched the next time a user visits the respective pages.
```bash
bundle exec rake anime_database:clear_cache
```

### Refresh Cache (Recommended)
Marks all cached entries as "stale". This triggers a background update when an anime is accessed, but allows the UI to show the old data in the meantime for a seamless experience.
```bash
bundle exec rake anime_database:refresh_cache
```

### Sync Airing Anime
Manually triggers a background sync for all anime currently marked as "airing" in the database.
```bash
bundle exec rake anime_database:sync_airing
```

### Sync Specific Anime
Refresh a single anime by its MyAnimeList ID.
```bash
bundle exec rake anime_database:sync_anime[MAL_ID]
```
*Example: `bundle exec rake anime_database:sync_anime[54857]` (Re:Zero Season 3)*

## Stale Thresholds
The plugin automatically considers data stale after certain periods:
- **Currently Airing**: 6 hours
- **Finished Airing**: 7 days
- **Upcoming**: 24 hours
- **Episodes**: 6 hours (for airing anime)

When data is stale, the library will return the cached version immediately and queue a background job to update it from the APIs.
