import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { service } from "@ember/service";

export default class IndexController extends Controller {
    @service router;
    @service siteSettings;
    @tracked watchlistData = {};
    @tracked activeAnimeId = null;

    queryParams = ["q", "type", "status", "genre", "sort"];

    @tracked q = null;
    @tracked type = null;
    @tracked status = null;
    @tracked genre = null;
    @tracked sort = this.siteSettings.anime_default_sort || "score";
    @tracked showFilters = false;

    @action
    toggleMenu(animeId) {
        if (this.activeAnimeId === animeId) {
            this.activeAnimeId = null;
        } else {
            this.activeAnimeId = animeId;
        }
    }

    constructor() {
        super(...arguments);
        this.showFilters = !!(this.type || this.status || this.genre || (this.sort && this.sort !== this.siteSettings.anime_default_sort));
    }

    @action
    toggleFilters() {
        this.showFilters = !this.showFilters;
    }

    @action
    updateSearch(query) {
        const value = query || null;
        this.set("q", value);
        this.router.transitionTo("anime.index", {
            queryParams: { q: value }
        });
    }

    @action
    updateFilter(type, value) {
        const val = value || null;
        this.set(type, val);
        let qp = {};
        qp[type] = val;
        this.router.transitionTo("anime.index", {
            queryParams: qp
        });
    }

    @action
    resetFilters() {
        const defaultSort = this.siteSettings.anime_default_sort || "score";
        this.setProperties({
            q: null,
            type: null,
            status: null,
            genre: null,
            sort: defaultSort
        });
        this.router.transitionTo("anime.index", {
            queryParams: {
                q: null,
                type: null,
                status: null,
                genre: null,
                sort: defaultSort
            }
        });
    }

    @action
    async refreshWatchlist() {
        try {
            const result = await ajax("/anime/watchlist");
            const data = {};
            if (result && result.data) {
                result.data.forEach(item => {
                    data[item.anime_id] = item.status;
                });
            }
            this.watchlistData = data;
        } catch (e) {
            console.error("Failed to refresh watchlist:", e);
        }
    }
}
