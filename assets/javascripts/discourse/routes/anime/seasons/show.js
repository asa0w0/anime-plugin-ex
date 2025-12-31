import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class SeasonsShowRoute extends Route {
    model(params) {
        const url = `/anime/seasons/${params.year}/${params.season}`;
        return ajax(url);
    }

    setupController(controller, model) {
        super.setupController(controller, model);
        const params = this.paramsFor("anime.seasons.show");
        controller.set("selectedYear", parseInt(params.year));
        controller.set("selectedSeason", params.season);
    }
}
