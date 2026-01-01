import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class SeasonsShowController extends Controller {
    @service router;
    @tracked watchlistData = {};

    selectedYear = null;
    selectedSeason = null;

    seasons = ["winter", "spring", "summer", "fall"];

    @action
    async refreshWatchlist() {
        try {
            const result = await ajax("/anime/watchlist");
            const data = {};
            if (result && result.data) {
                result.data.forEach(item => {
                    data[item.anime_id] = item.status;
                });
            }
            this.watchlistData = data;
        } catch (e) {
            console.error("Failed to refresh watchlist:", e);
        }
    }

    get currentYear() {
        return new Date().getFullYear();
    }

    get years() {
        const current = this.currentYear;
        return [current + 1, current, current - 1, current - 2];
    }

    @action
    changeSeason(year, season) {
        this.router.transitionTo("anime.seasons.show", year, season);
    }
}
