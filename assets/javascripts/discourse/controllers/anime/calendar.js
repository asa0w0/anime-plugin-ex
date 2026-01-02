import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class CalendarController extends Controller {
    @tracked showOnlyWatchlist = false;
    @tracked sortBy = "countdown"; // countdown, popularity, title, date
    @tracked viewMode = "grid"; // grid or list

    get sortOptions() {
        return [
            { value: "countdown", label: "Next Episode" },
            { value: "popularity", label: "Popularity" },
            { value: "title", label: "Title (A-Z)" },
            { value: "date", label: "Release Date" }
        ];
    }

    get animeList() {
        if (!this.model?.data) {
            return [];
        }

        let data = Array.isArray(this.model.data) ? this.model.data : [];
        const watchlistIds = this.model.watchlist_anime_ids || [];

        // Filter by watchlist if enabled
        if (this.showOnlyWatchlist && watchlistIds.length > 0) {
            data = data.filter(anime => {
                const animeId = anime.mal_id.toString();
                return watchlistIds.includes(animeId);
            });
        }

        // Add countdown information
        data = data.map(anime => {
            return {
                ...anime,
                countdown: this.calculateCountdown(anime),
                nextEpisodeTime: this.getNextEpisodeTime(anime)
            };
        });

        // Sort
        return this.sortAnimeList(data);
    }

    sortAnimeList(data) {
        const sorted = [...data];

        switch (this.sortBy) {
            case "countdown":
                sorted.sort((a, b) => {
                    if (!a.countdown && !b.countdown) return 0;
                    if (!a.countdown) return 1;
                    if (!b.countdown) return -1;
                    return a.countdown.totalSeconds - b.countdown.totalSeconds;
                });
                break;
            case "popularity":
                sorted.sort((a, b) => (b.members || 0) - (a.members || 0));
                break;
            case "title":
                sorted.sort((a, b) => (a.title || "").localeCompare(b.title || ""));
                break;
            case "date":
                sorted.sort((a, b) => {
                    const aDate = new Date(a.aired?.from || 0);
                    const bDate = new Date(b.aired?.from || 0);
                    return bDate - aDate;
                });
                break;
        }

        return sorted;
    }

    calculateCountdown(anime) {
        // Prefer precise AniList timestamp
        if (anime.airing_at) {
            const now = new Date();
            const airDate = new Date(anime.airing_at * 1000);
            const diff = airDate - now;

            if (diff > 0) {
                const totalSeconds = Math.floor(diff / 1000);
                const days = Math.floor(totalSeconds / 86400);
                const hours = Math.floor((totalSeconds % 86400) / 3600);
                const minutes = Math.floor((totalSeconds % 3600) / 60);

                return {
                    days, hours, minutes, totalSeconds,
                    formatted: this.formatCountdown(days, hours, minutes)
                };
            }
        }

        if (!anime.broadcast?.day || !anime.broadcast?.time) {
            return null;
        }

        const now = new Date();
        const dayMap = {
            "monday": 1, "mondays": 1,
            "tuesday": 2, "tuesdays": 2,
            "wednesday": 3, "wednesdays": 3,
            "thursday": 4, "thursdays": 4,
            "friday": 5, "fridays": 5,
            "saturday": 6, "saturdays": 6,
            "sunday": 0, "sundays": 0
        };

        const targetDay = dayMap[anime.broadcast.day.toLowerCase()];
        if (targetDay === undefined) return null;

        // Parse JST time
        const [jstHours, jstMinutes] = anime.broadcast.time.split(':').map(Number);

        // Create next occurrence in JST
        const nextAir = new Date();
        nextAir.setUTCHours(jstHours - 9, jstMinutes, 0, 0); // JST is UTC+9

        // Find next occurrence of target day
        const currentDay = now.getDay();
        let daysUntil = targetDay - currentDay;
        if (daysUntil < 0 || (daysUntil === 0 && now > nextAir)) {
            daysUntil += 7;
        }

        nextAir.setDate(now.getDate() + daysUntil);

        const diff = nextAir - now;
        const totalSeconds = Math.floor(diff / 1000);
        const days = Math.floor(totalSeconds / 86400);
        const hours = Math.floor((totalSeconds % 86400) / 3600);
        const minutes_remaining = Math.floor((totalSeconds % 3600) / 60);

        return {
            days,
            hours,
            minutes: minutes_remaining,
            totalSeconds,
            formatted: this.formatCountdown(days, hours, minutes_remaining)
        };
    }

    formatCountdown(days, hours, minutes) {
        if (days > 0) {
            return `${days}d ${hours}h`;
        } else if (hours > 0) {
            return `${hours}h ${minutes}m`;
        } else {
            return `${minutes}m`;
        }
    }

    getNextEpisodeTime(anime) {
        if (anime.airing_at) {
            return new Date(anime.airing_at * 1000).toLocaleTimeString([], {
                hour: '2-digit', minute: '2-digit', hour12: false
            });
        }
        if (!anime.broadcast?.time) return null;

        const [hours, minutes] = anime.broadcast.time.split(':').map(Number);
        const jstDate = new Date();
        jstDate.setUTCHours(hours - 9, minutes, 0, 0);

        return jstDate.toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit',
            hour12: false
        });
    }

    truncateSynopsis(text, maxLength = 180) {
        if (!text) return "";
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength).trim() + "...";
    }

    @action
    toggleWatchlistFilter() {
        this.showOnlyWatchlist = !this.showOnlyWatchlist;
    }

    @action
    changeSortBy(event) {
        this.sortBy = event.target.value;
    }

    @action
    toggleViewMode() {
        this.viewMode = this.viewMode === "grid" ? "list" : "grid";
    }
}
