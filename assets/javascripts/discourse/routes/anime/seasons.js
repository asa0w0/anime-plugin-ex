import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class SeasonsRoute extends Route {
    templateName = "anime/seasons";
    controllerName = "anime/seasons";

    model(params) {
        let url = "/anime/seasons";
        if (params.year && params.season) {
            url = `/anime/seasons/${params.year}/${params.season}`;
        }
        return ajax(url);
    }

    setupController(controller, model) {
        super.setupController(controller, model);
        const params = this.paramsFor(this.routeName);
        controller.selectedYear = params.year || controller.selectedYear || new Date().getFullYear();
        controller.selectedSeason = params.season || controller.selectedSeason || this.getCurrentSeason();
        controller.loading = false;
    }

    getCurrentSeason() {
        const month = new Date().getMonth();
        if (month <= 2) return "winter";
        if (month <= 5) return "spring";
        if (month <= 8) return "summer";
        return "fall";
    }
}
