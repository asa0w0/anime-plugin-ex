import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class CalendarController extends Controller {
    @tracked showOnlyWatchlist = false;

    days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

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
        const data = Array.isArray(this.model.data) ? this.model.data : [];

        console.log("Calendar: Total anime in schedule:", data.length);
        if (data.length > 0) {
            console.log("Calendar: First anime structure:", data[0]);
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
                console.log(`Anime: ${anime.title} - Broadcast Day: ${broadcastDay} -> ${day}`);
                if (grouped[day]) {
                    grouped[day].push(anime);
                } else {
                    console.warn(`Unrecognized day: ${day}`);
                }
            } else {
                console.log(`Anime ${anime.title} has no broadcast day`);
            }
        });

        console.log("Calendar: Grouped by day:", Object.keys(grouped).map(day => `${day}: ${grouped[day].length}`));
        return grouped;
    }

    @action
    toggleWatchlistFilter() {
        this.showOnlyWatchlist = !this.showOnlyWatchlist;
    }
}
