import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class IndexRoute extends Route {
    @service currentUser;

    queryParams = {
        q: { refreshModel: true },
        type: { refreshModel: true },
        status: { refreshModel: true },
        genre: { refreshModel: true },
        sort: { refreshModel: true }
    };

    async model(params) {
        const response = await ajax("/anime", { data: params });
        const animeData = response && response.data ? response.data : [];

        let watchlistData = {};
        if (this.currentUser) {
            try {
                const watchlist = await ajax("/anime/watchlist");
                if (watchlist && watchlist.data) {
                    watchlist.data.forEach(item => {
                        watchlistData[item.anime_id] = item.status;
                    });
                }
            } catch (e) {
                console.error("Failed to load watchlist:", e);
            }
        }

        return {
            anime: animeData,
            watchlistData: watchlistData
        };
    }

    setupController(controller, model) {
        super.setupController(controller, model);
        controller.watchlistData = model.watchlistData;
    }
}
