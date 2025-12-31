import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class CalendarController extends Controller {
    @tracked showOnlyWatchlist = false;

    allDays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

    // Get days starting from today
    get days() {
        const today = new Date().getDay(); // 0 = Sunday, 1 = Monday, etc.
        const dayMap = [6, 0, 1, 2, 3, 4, 5]; // Map JS day to our array index
        const todayIndex = dayMap[today];

        // Reorder array to start with today
        return [
            ...this.allDays.slice(todayIndex),
            ...this.allDays.slice(0, todayIndex)
        ];
    }

    // Convert JST time to user's local time
    convertJSTToLocal(jstTimeString) {
        if (!jstTimeString) return null;

        // Parse time like "23:30" from JST
        const [hours, minutes] = jstTimeString.split(':').map(Number);

        // Create date in JST (UTC+9)
        const jstDate = new Date();
        jstDate.setUTCHours(hours - 9, minutes, 0, 0); // Convert JST to UTC

        // Format in user's local time
        return jstDate.toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit',
            hour12: false
        });
    }

    get todayDay() {
        const today = new Date().getDay();
        const dayMap = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
        return dayMap[today];
    }

    get dayLabels() {
        return {
            monday: "Monday",
            tuesday: "Tuesday",
            wednesday: "Wednesday",
            thursday: "Thursday",
            friday: "Friday",
            saturday: "Saturday",
            sunday: "Sunday"
        };
    }

    get scheduleByDay() {
        if (!this.model?.data) {
            console.log("Calendar: No model data");
            return {};
        }

        // Jikan /schedules endpoint returns data array directly
        let data = Array.isArray(this.model.data) ? this.model.data : [];
        const watchlistIds = this.model.watchlist_anime_ids || [];

        console.log("Calendar: Total anime:", data.length, "| Watchlist:", watchlistIds.length);

        // Filter by watchlist if enabled
        if (this.showOnlyWatchlist && watchlistIds.length > 0) {
            data = data.filter(anime => {
                const animeId = anime.mal_id.toString();
                return watchlistIds.includes(animeId);
            });
            console.log("Calendar: Filtered to", data.length, "watchlist anime");
        }

        if (data.length > 0) {
            console.log("Calendar: First anime:", data[0].title);
        }

        // Group anime by day
        const grouped = {
            monday: [],
            tuesday: [],
            wednesday: [],
            thursday: [],
            friday: [],
            saturday: [],
            sunday: []
        };

        data.forEach(anime => {
            // Jikan API uses "broadcast" object with "day" field in PLURAL form
            const broadcastDay = anime.broadcast?.day;
            if (broadcastDay) {
                // Convert plural to singular: "thursdays" -> "thursday"
                let day = broadcastDay.toLowerCase().trim();
                if (day.endsWith('s')) {
                    day = day.slice(0, -1); // Remove trailing 's'
                }
                if (grouped[day]) {
                    grouped[day].push(anime);
                }
            }
        });

        console.log("Calendar: Grouped by day:", Object.keys(grouped).map(day => `${day}: ${grouped[day].length}`));
        return grouped;
    }

    @action
    toggleWatchlistFilter() {
        this.showOnlyWatchlist = !this.showOnlyWatchlist;
        console.log("Calendar: Watchlist filter toggled to:", this.showOnlyWatchlist);
    }
}
