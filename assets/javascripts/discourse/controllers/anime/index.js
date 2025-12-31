import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class IndexController extends Controller {
    @tracked watchlistIds = [];

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
