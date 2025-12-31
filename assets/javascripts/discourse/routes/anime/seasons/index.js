import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class SeasonsIndexRoute extends Route {
    redirect() {
        const year = new Date().getFullYear();
        const season = this.getCurrentSeason();
        this.replaceWith("anime.seasons.show", year, season);
    }

    getCurrentSeason() {
        const month = new Date().getMonth();
        if (month <= 2) return "winter";
        if (month <= 5) return "spring";
        if (month <= 8) return "summer";
        return "fall";
    }
}
