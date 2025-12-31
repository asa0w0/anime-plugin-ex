import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

export default class IndexController extends Controller {
    @service router;
    @tracked watchlistIds = [];

    queryParams = ["q", "type", "status", "genre", "sort"];

    @tracked q = null;
    @tracked type = null;
    @tracked status = null;
    @tracked genre = null;
    @tracked sort = "score";

    @action
    updateSearch(query) {
        const value = query || null;
        this.set("q", value);
        this.transitionToRoute("anime.index", {
            queryParams: { q: value }
        });
    }

    @action
    updateFilter(type, value) {
        const val = value || null;
        this.set(type, val);
        let qp = {};
        qp[type] = val;
        this.transitionToRoute("anime.index", { queryParams: qp });
    }

    @action
    resetFilters() {
        this.setProperties({
            q: null,
            type: null,
            status: null,
            genre: null,
            sort: "score"
        });
        this.transitionToRoute("anime.index", {
            queryParams: {
                q: null,
                type: null,
                status: null,
                genre: null,
                sort: "score"
            }
        });
    }

    @action
    async refreshWatchlist() {
        try {
            const watchlist = await ajax("/anime/watchlist");
            this.watchlistIds = watchlist.data.map(item => item.anime_id);
        } catch (e) {
            console.error("Failed to refresh watchlist:", e);
        }
    }
}
