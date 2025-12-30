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
    createDiscussion(type = "general", episodeNumber = null) {
        const categoryId = parseInt(this.siteSettings.anime_database_category, 10);
        const isEpisode = type === "episodes" || episodeNumber !== null;

        let title = `Discussion: ${this.model.title}`;
        if (episodeNumber) {
            title = `[Episode ${episodeNumber}] ${this.model.title}`;
        } else if (isEpisode) {
            title = `Episodes Discussion: ${this.model.title}`;
        }

        const draftKey = episodeNumber
            ? `anime-ep-${episodeNumber}-${this.model.mal_id}`
            : `anime-${type}-${this.model.mal_id}`;

        const composerData = {
            action: "createTopic",
            draftKey: draftKey,
            topicTitle: title,
            topicCategoryId: categoryId > 0 ? categoryId : null,
            topicBody: `Discussing ${this.model.title}${episodeNumber ? ` - Episode ${episodeNumber}` : ""}\n\n[quote]\n${this.model.synopsis}\n[/quote]`,
            anime_mal_id: this.model.mal_id.toString(),
        };

        if (episodeNumber) {
            composerData.anime_episode_number = episodeNumber.toString();
        }

        this.composer.open(composerData);
    }

    get generalTopics() {
        return (this.model.topics || []).filter(t => !t.episode_number);
    }

    get episodeTopics() {
        return (this.model.topics || []).filter(t => t.episode_number).sort((a, b) => {
            return parseInt(a.episode_number) - parseInt(b.episode_number);
        });
    }

    get episodeList() {
        const count = this.model?.episodes || 0;
        if (count <= 0) {
            return [];
        }
        // Limit to 1000 episodes to avoid browser crash
        const limit = Math.min(count, 1000);
        return Array.from({ length: limit }, (_, i) => i + 1);
    }
}
