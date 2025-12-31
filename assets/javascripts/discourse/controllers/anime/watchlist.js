import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class WatchlistController extends Controller {
    get watching() {
        return (this.model || []).filter(item => item.status === "watching");
    }

    get planned() {
        return (this.model || []).filter(item => item.status === "plan_to_watch");
    }

    get completed() {
        return (this.model || []).filter(item => item.status === "completed");
    }

    get onHold() {
        return (this.model || []).filter(item => item.status === "on_hold");
    }

    get dropped() {
        return (this.model || []).filter(item => item.status === "dropped");
    }

    @action
    async removeFromWatchlist(animeId) {
        try {
            await ajax(`/anime/watchlist/${animeId}`, { type: "DELETE" });
            // Update the model to trigger re-render of getters
            this.set("model", this.model.filter(item => item.anime_id !== animeId));
        } catch (error) {
            console.error("Error removing from watchlist:", error);
        }
    }
}
