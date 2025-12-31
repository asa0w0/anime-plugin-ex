import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class UserWatchlistController extends Controller {
    @service currentUser;

    get watching() {
        return (this.model || []).filter(item => item.status === "watching");
    }

    get planned() {
        return (this.model || []).filter(item => item.status === "plan_to_watch");
    }

    get onHold() {
        return (this.model || []).filter(item => item.status === "on_hold");
    }

    get dropped() {
        return (this.model || []).filter(item => item.status === "dropped");
    }

    get completed() {
        return (this.model || []).filter(item => item.status === "completed");
    }

    get isOwner() {
        return this.currentUser && this.user && this.currentUser.username === this.user.username;
    }

    @action
    async removeFromWatchlist(animeId) {
        try {
            await ajax(`/anime/watchlist/${animeId}`, { type: "DELETE" });
            this.set("model", this.model.filter(item => item.anime_id !== animeId));
        } catch (error) {
            console.error("Error removing from watchlist:", error);
        }
    }
}
