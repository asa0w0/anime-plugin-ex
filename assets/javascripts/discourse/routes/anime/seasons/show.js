import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import RSVP from "rsvp";
import { service } from "@ember/service";

export default class SeasonsShowRoute extends Route {
    @service currentUser;

    async model(params) {
        const url = `/anime/seasons/${params.year}/${params.season}`;

        const promises = {
            anime: ajax(url).catch(() => ({ data: [] })),
            watchlist: Promise.resolve({ data: [] })
        };

        if (this.currentUser) {
            promises.watchlist = ajax("/anime/watchlist").catch(() => ({ data: [] }));
        }

        const results = await RSVP.hash(promises);

        const watchlistData = {};
        if (results.watchlist && results.watchlist.data) {
            results.watchlist.data.forEach(item => {
                watchlistData[item.anime_id] = item.status;
            });
        }

        return {
            anime: results.anime,
            watchlistData
        };
    }

    setupController(controller, model) {
        super.setupController(controller, model);
        const params = this.paramsFor("anime.seasons.show");
        controller.set("selectedYear", parseInt(params.year));
        controller.set("selectedSeason", params.season);
        controller.set("watchlistData", model.watchlistData);
        // The template expects 'this.model.data' for anime. 
        // We are changing 'model' to be { anime: ..., watchlistData: ... }
        // So in template it will be this.model.anime.data
        // We should probably explicitly set the model for the controller or adjust the template.
        // Let's adjust controller to have 'anime' property or just rely on model.anime.
    }
}
