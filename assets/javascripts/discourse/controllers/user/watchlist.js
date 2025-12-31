import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class UserWatchlistController extends Controller {
    @service currentUser;

    get watchlistData() {
        const data = {};
        if (this.model) {
            this.model.forEach(item => {
                data[item.anime_id] = item.status;
            });
        }
        return data;
    }

    transformItem(item) {
        return {
            mal_id: item.anime_id,
            title: item.title,
            images: {
                jpg: {
                    image_url: item.image_url
                }
            },
            type: "TV", // Placeholder as detailed info isn't stored in watchlist
            score: null,
            episodes: null,
            genres: []
        };
    }

    get watching() {
        return (this.model || [])
            .filter(item => item.status === "watching")
            .map(item => this.transformItem(item));
    }

    get planned() {
        return (this.model || [])
            .filter(item => item.status === "plan_to_watch")
            .map(item => this.transformItem(item));
    }

    get onHold() {
        return (this.model || [])
            .filter(item => item.status === "on_hold")
            .map(item => this.transformItem(item));
    }

    get dropped() {
        return (this.model || [])
            .filter(item => item.status === "dropped")
            .map(item => this.transformItem(item));
    }

    get completed() {
        return (this.model || [])
            .filter(item => item.status === "completed")
            .map(item => this.transformItem(item));
    }

    get isOwner() {
        return this.currentUser && this.user && this.currentUser.username === this.user.username;
    }

    @action
    async refreshWatchlist() {
        try {
            // Re-fetch the watchlist for the current user being viewed
            const username = this.user.username;
            const result = await ajax(`/anime/watchlist/${username}`);
            // Update the model directly
            this.set("model", result.data);
        } catch (e) {
            console.error("Failed to refresh watchlist:", e);
        }
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
