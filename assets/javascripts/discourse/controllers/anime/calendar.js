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
            return {};
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

        this.model.data.forEach(anime => {
            const day = anime.broadcast?.day?.toLowerCase();
            if (day && grouped[day]) {
                grouped[day].push(anime);
            }
        });

        return grouped;
    }

    @action
    toggleWatchlistFilter() {
        this.showOnlyWatchlist = !this.showOnlyWatchlist;
    }
}
