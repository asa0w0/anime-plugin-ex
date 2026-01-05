# Anime Database Plugin Cache Management

This plugin uses a local cache to store anime and episode data for improved performance and to avoid rate-limiting from external APIs.

## Rake Tasks

### Development
In a local development environment, you can run:
```bash
bundle exec rake anime_database:clear_cache
```

### Production (Discourse Container)
In a production environment (after running `./launcher enter app`), you **must** run the tasks as the `discourse` user and specify the environment `RAILS_ENV=production`. 

If you run as `root`, the database connection will fail with a "Peer authentication failed" error.

**Correct Command:**
```bash
sudo -u discourse RAILS_ENV=production bundle exec rake anime_database:clear_cache
```

---

## Available Commands

| Command | Description |
| :--- | :--- |
| `anime_database:clear_cache` | Completely removes all cached anime and episode data. |
| `anime_database:refresh_cache` | Marks all cached entries as "stale" to trigger background refresh on next access. |
| `anime_database:sync_airing` | Manually triggers a background sync for all currently airing anime. |
| `anime_database:sync_anime[MAL_ID]` | Refreshes a single anime by its ID (e.g., `sync_anime[54857]`). |

*Note: In production, always prefix with `sudo -u discourse RAILS_ENV=production `.*

## Automatic Refresh Thresholds
- **Currently Airing**: Updates every 6 hours
- **Finished Airing**: Updates every 7 days
- **Upcoming**: Updates every 24 hours
