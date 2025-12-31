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

        // Create anime info card with image and details
        const animeUrl = `${window.location.origin}/anime/${this.model.mal_id}`;
        const imageUrl = this.model.images?.jpg?.large_image_url || this.model.images?.jpg?.image_url;
        const score = this.model.score || "N/A";
        const episodes = this.model.episodes || "?";
        const status = this.model.status || "Unknown";
        const year = this.model.year || this.model.aired?.from?.split('-')[0] || "?";

        const topicBody = `### ${isEpisode ? '📺 Episode Discussion' : '💬 General Discussion'}

![${this.model.title}|690x388](${imageUrl})

**[View on Anime Database](${animeUrl})**

| | |
|---|---|
| **Score** | ⭐ ${score} |
| **Episodes** | ${episodes} |
| **Status** | ${status} |
| **Year** | ${year} |
| **Type** | ${this.model.type || "?"} |

---

${isEpisode ? 'Share your thoughts about the episodes!' : 'What do you think about this anime?'}`;

        this.composer.open({
            action: "createTopic",
            draftKey: draftKey,
            topicTitle: title,
            topicCategoryId: categoryId > 0 ? categoryId : null,
            topicBody: topicBody,
            anime_mal_id: this.model.mal_id.toString(),
        });
    }
}
