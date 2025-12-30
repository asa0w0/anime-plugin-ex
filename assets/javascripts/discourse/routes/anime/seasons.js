import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class SeasonsRoute extends Route {
    model(params) {
        const year = params.year || new Date().getFullYear();
        const season = params.season || this.getCurrentSeason();
        const url = `/anime/seasons/${year}/${season}`;
        return ajax(url);
    }

    setupController(controller, model) {
        super.setupController(controller, model);
        const params = this.paramsFor("anime.seasons");
        controller.selectedYear = params.year || new Date().getFullYear();
        controller.selectedSeason = params.season || this.getCurrentSeason();
    }

    getCurrentSeason() {
        const month = new Date().getMonth();
        if (month <= 2) return "winter";
        if (month <= 5) return "spring";
        if (month <= 8) return "summer";
        return "fall";
    }
}
