import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class ShowController extends Controller {
    @service composer;
    @service currentUser;
    @service("site-settings") siteSettings;

    @tracked selectedStatus = null;
    @tracked _manualStatus = null;

    get watchlistStatus() {
        return this._manualStatus || this.model?.watchlist_status;
    }

    get displayWatchlistStatus() {
        const status = this.watchlistStatus;
        if (!status) {
            return "";
        }
        return status.charAt(0).toUpperCase() + status.slice(1);
    }

    @action
    changeStatus(event) {
        this.selectedStatus = event.target.value;
    }

    @action
    async saveToWatchlist() {
        if (!this.currentUser || !this.selectedStatus) {
            return;
        }

        try {
            await ajax("/anime/watchlist", {
                type: "POST",
                data: {
                    anime_id: this.model.mal_id,
                    status: this.selectedStatus,
                    title: this.model.title,
                    image_url: this.model.images.jpg.image_url,
                }
            });
            this._manualStatus = this.selectedStatus;
            this.selectedStatus = null; // Reset selection after save
        } catch (error) {
            console.error("Error updating watchlist:", error);
        }
    }

    @action
    createDiscussion(type = "general") {
        const categoryId = parseInt(this.siteSettings.anime_database_category, 10);
        const isEpisode = type === "episodes";

        const title = isEpisode
            ? `Episodes Discussion: ${this.model.title}`
            : `Discussion: ${this.model.title}`;

        const draftKey = `anime-${type}-${this.model.mal_id}`;

        this.composer.open({
            action: "createTopic",
            draftKey: draftKey,
            topicTitle: title,
            topicCategoryId: categoryId > 0 ? categoryId : null,
            topicBody: `Discussing ${this.model.title}\n\n[quote]\n${this.model.synopsis}\n[/quote]`,
            anime_mal_id: this.model.mal_id.toString(),
        });
    }
}
