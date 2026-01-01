import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class SeasonsIndexRoute extends Route {
    @service router;

    beforeModel() {
        const year = new Date().getFullYear();
        const season = this.getCurrentSeason();
        this.router.replaceWith("anime.seasons.show", year, season);
    }

    getCurrentSeason() {
        const month = new Date().getMonth();
        if (month <= 2) return "winter";
        if (month <= 5) return "spring";
        if (month <= 8) return "summer";
        return "fall";
    }
}
