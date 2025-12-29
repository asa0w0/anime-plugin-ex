# Discourse Anime Database Plugin

A premium Discourse plugin that adds a MyAnimeList-style database to your forum.

## Screenshots

![Anime Database Overview](/home/asa/.gemini/antigravity/brain/49f35ab2-478e-4820-809c-66b9c0490c6e/anime_database_overview_mockup_1767046061816.png)
*Anime Overview Grid*

![Anime Detail Page](/home/asa/.gemini/antigravity/brain/49f35ab2-478e-4820-809c-66b9c0490c6e/anime_detail_page_mockup_1767046082999.png)
*Detailed Anime View with Discussion*

## Features

- **Anime Overview**: A beautiful grid view of top anime with ratings.
- **Detailed Pages**: Detailed information for each anime, including synopsis, genres, and metadata.
- **Trailers**: Embedded YouTube trailers for anime.
- **Discussion Integration**: 
  - Automatically links to existing forum topics using the `anime_mal_id` custom field.
  - Allows users to start new discussions directly from the anime page.
- **Premium UI**: Modern design with glassmorphism, smooth animations, and responsive layout.

## Installation

1. Add the plugin to your Discourse installation's `app.yml`.
2. Rebuild your Discourse container.
3. Enable the `anime_database_enabled` site setting.

## Usage

- Navigate to `/anime` on your forum to view the database.
- Click on any anime card to view details and join the discussion.

## Technology Stack

- **Backend**: Ruby on Rails (Discourse Plugin API)
- **Frontend**: Ember.js
- **Data Source**: Jikan API (Unofficial MyAnimeList API)
- **Styling**: SCSS with Discourse Design Tokens

## License

MIT
