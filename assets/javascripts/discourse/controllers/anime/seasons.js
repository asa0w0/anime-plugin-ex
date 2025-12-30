import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class SeasonsController extends Controller {
    @service router;

    @tracked selectedYear;
    @tracked selectedSeason;
    @tracked loading = false;

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
        this.loading = true;
        this.selectedYear = year;
        this.selectedSeason = season;
        this.router.transitionTo("anime.seasons_detail", year, season);
    }
}
