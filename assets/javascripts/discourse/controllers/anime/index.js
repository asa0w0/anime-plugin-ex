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
        this.router.transitionTo({ queryParams: { q: query || null } });
    }

    @action
    updateFilter(type, value) {
        let qp = {};
        qp[type] = value || null;
        this.router.transitionTo({ queryParams: qp });
    }

    @action
    resetFilters() {
        this.router.transitionTo({
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
