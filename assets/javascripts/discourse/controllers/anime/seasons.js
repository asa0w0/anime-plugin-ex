import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class SeasonsController extends Controller {
    @service router;

    @tracked selectedYear;
    @tracked selectedSeason;

    seasons = ["winter", "spring", "summer", "fall"];

    get currentYear() {
        return new Date().getFullYear();
    }

    get years() {
        const current = this.currentYear;
        return [current + 1, current, current - 1, current - 2];
    }

    get animeList() {
        return this.model?.data || [];
    }

    get isLoading() {
        return !this.model || this.model.length === 0;
    }

    @action
    changeSeason(year, season) {
        this.router.transitionTo("anime.seasons", year, season);
    }
}
