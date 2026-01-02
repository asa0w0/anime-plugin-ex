import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class WatchlistController extends Controller {
    @tracked searchTerm = "";
    @tracked activeFilter = "all";

    vibrate(duration = 10) {
        if ("vibrate" in navigator) {
            navigator.vibrate(duration);
        }
    }

    get filteredModel() {
        let items = this.model || [];
        if (this.searchTerm) {
            const query = this.searchTerm.toLowerCase();
            items = items.filter(item => item.title.toLowerCase().includes(query));
        }
        return items;
    }

    get watching() {
        return this.filteredModel.filter(item => item.status === "watching");
    }

    get planned() {
        return this.filteredModel.filter(item => item.status === "plan_to_watch");
    }

    get completed() {
        return this.filteredModel.filter(item => item.status === "completed");
    }

    get onHold() {
        return this.filteredModel.filter(item => item.status === "on_hold");
    }

    get dropped() {
        return this.filteredModel.filter(item => item.status === "dropped");
    }

    @action
    setSearchTerm(event) {
        this.searchTerm = event.target.value;
    }

    @action
    clearSearch() {
        this.vibrate(5);
        this.searchTerm = "";
    }

    @action
    setActiveFilter(filter) {
        this.vibrate(5);
        this.activeFilter = filter;
    }

    @action
    async removeFromWatchlist(animeId) {
        this.vibrate(15);
        try {
            await ajax(`/anime/watchlist/${animeId}`, { type: "DELETE" });
            this.set("model", this.model.filter(item => item.anime_id !== animeId));
            this.vibrate([10, 50, 10]); // Success pattern
        } catch (error) {
            console.error("Error removing from watchlist:", error);
        }
    }
}
