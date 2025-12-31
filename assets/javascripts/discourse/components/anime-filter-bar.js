import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class AnimeFilterBar extends Component {
    types = [
        { id: "tv", name: "TV" },
        { id: "movie", name: "Movie" },
        { id: "ova", name: "OVA" },
        { id: "special", name: "Special" },
        { id: "ona", name: "ONA" },
        { id: "music", name: "Music" }
    ];

    statuses = [
        { id: "airing", name: "Airing" },
        { id: "complete", name: "Complete" },
        { id: "upcoming", name: "Upcoming" }
    ];

    sorts = [
        { id: "score", name: "Score" },
        { id: "title", name: "Title" },
        { id: "popularity", name: "Popularity" },
        { id: "favorites", name: "Favorites" },
        { id: "start_date", name: "Start Date" }
    ];

    // Common MAL genres
    genres = [
        { id: "1", name: "Action" },
        { id: "2", name: "Adventure" },
        { id: "4", name: "Comedy" },
        { id: "8", name: "Drama" },
        { id: "10", name: "Fantasy" },
        { id: "37", name: "Supernatural" },
        { id: "22", name: "Romance" },
        { id: "24", name: "Sci-Fi" },
        { id: "30", name: "Sports" }
    ];

    @action
    onSelectChange(type, event) {
        this.args.onChange(type, event.target.value);
    }

    @action
    resetFilters() {
        this.args.onReset();
    }
}
