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
    @tracked currentPage = 1;
    @tracked hasNextPage = false;
    @tracked loadingMore = false;
    @tracked extraAnime = [];

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
        this.hasNextPage = this.model?.hasNextPage || false;
    }

    get fullAnimeList() {
        return [...(this.model?.anime || []), ...this.extraAnime];
    }

    @action
    async loadMore() {
        if (this.loadingMore || !this.hasNextPage) return;

        this.loadingMore = true;
        this.currentPage++;

        try {
            const params = {
                page: this.currentPage,
                q: this.q,
                type: this.type,
                status: this.status,
                genre: this.genre,
                sort: this.sort
            };

            const result = await ajax("/anime", { data: params });

            if (result && result.data) {
                this.extraAnime = [...this.extraAnime, ...result.data];
                this.hasNextPage = result.pagination?.has_next_page || false;
            } else {
                this.hasNextPage = false;
            }
        } catch (e) {
            console.error("Failed to load more anime:", e);
            this.hasNextPage = false;
        } finally {
            this.loadingMore = false;
        }
    }

    @action
    toggleFilters() {
        this.showFilters = !this.showFilters;
    }

    @action
    updateSearch(query) {
        const value = query || null;
        this.resetPagination();
        this.set("q", value);
        this.router.transitionTo("anime.index", {
            queryParams: { q: value }
        });
    }

    @action
    updateFilter(type, value) {
        const val = value || null;
        this.resetPagination();
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
        this.resetPagination();
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

    resetPagination() {
        this.currentPage = 1;
        this.extraAnime = [];
        this.hasNextPage = false;
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
