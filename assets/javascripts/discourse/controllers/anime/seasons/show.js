import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class SeasonsShowController extends Controller {
    @service router;

    selectedYear = null;
    selectedSeason = null;

    seasons = ["winter", "spring", "summer", "fall"];

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
