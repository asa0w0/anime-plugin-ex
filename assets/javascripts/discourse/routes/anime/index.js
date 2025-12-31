import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class IndexRoute extends Route {
    @service currentUser;

    async model() {
        const animeData = await ajax("/anime").then((data) => data.data);

        let watchlistIds = [];
        if (this.currentUser) {
            try {
                const watchlist = await ajax("/anime/watchlist");
                watchlistIds = watchlist.data.map(item => item.anime_id);
            } catch (e) {
                console.error("Failed to load watchlist:", e);
            }
        }

        return {
            anime: animeData,
            watchlistIds: watchlistIds
        };
    }
}
