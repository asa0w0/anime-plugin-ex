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
            this.selectedStatus = null;
        } catch (error) {
            console.error("Error updating watchlist:", error);
        }
    }

    @action
    async createDiscussion(type = "general", episode = null) {
        const categoryId = parseInt(this.siteSettings.anime_database_category, 10);

        // For episode-specific discussions, use our custom API
        if (episode) {
            try {
                const result = await ajax(`/anime/${this.model.mal_id}/episodes/${episode.episode_number}/discussion`, {
                    type: "POST",
                    data: {
                        anime_title: this.model.title,
                        category_id: categoryId,
                        body: this.buildEpisodeBody(episode)
                    }
                });

                if (result.already_exists) {
                    window.location.href = result.topic_url;
                } else {
                    window.location.href = result.topic_url;
                }
            } catch (error) {
                console.error("Error creating episode discussion:", error);
                alert("Failed to create episode discussion. Please try again.");
            }
            return;
        }

        // For general discussions, use the normal composer
        const isEpisode = type === "episodes";
        const title = isEpisode
            ? `Episodes Discussion: ${this.model.title}`
            : `Discussion: ${this.model.title}`;

        const draftKey = `anime-${type}-${this.model.mal_id}`;
        const topicBody = this.buildGeneralBody(isEpisode);

        this.composer.open({
            action: "createTopic",
            draftKey: draftKey,
            topicTitle: title,
            topicCategoryId: categoryId > 0 ? categoryId : null,
            topicBody: topicBody,
            custom_fields: {
                anime_mal_id: this.model.mal_id.toString()
            }
        });
    }

    buildEpisodeBody(episode) {
        const animeUrl = `${window.location.origin}/anime/${this.model.mal_id}`;
        const imageUrl = this.model.images?.jpg?.large_image_url || this.model.images?.jpg?.image_url;
        const score = this.model.score || "N/A";
        const totalEpisodes = this.model.episodes || "?";
        const status = this.model.status || "Unknown";
        const year = this.model.year || this.model.aired?.from?.split('-')[0] || "?";

        let body = `### 📺 Episode ${episode.episode_number} Discussion\n\n`;
        body += `![${this.model.title}|690x388](${imageUrl})\n\n`;
        body += `**[View on Anime Database](${animeUrl})**\n\n`;
        body += `| | |\n|---|---|\n`;
        body += `| **Score** | ⭐ ${score} |\n`;
        body += `| **Episodes** | ${totalEpisodes} |\n`;
        body += `| **Status** | ${status} |\n`;
        body += `| **Year** | ${year} |\n`;
        body += `| **Type** | ${this.model.type || "?"} |\n\n`;
        body += `---\n\n`;
        body += `Episode ${episode.episode_number} of **${this.model.title}** has aired!\n\n`;

        if (episode.title) {
            body += `**Episode Title**: ${episode.title}\n`;
        }
        if (episode.aired_at) {
            body += `**Air Date**: ${episode.aired_at}\n\n`;
        }

        body += `---\n\nShare your thoughts about this episode! Please use spoiler tags for major plot points.`;

        return body;
    }

    buildGeneralBody(isEpisode) {
        const animeUrl = `${window.location.origin}/anime/${this.model.mal_id}`;
        const imageUrl = this.model.images?.jpg?.large_image_url || this.model.images?.jpg?.image_url;
        const score = this.model.score || "N/A";
        const totalEpisodes = this.model.episodes || "?";
        const status = this.model.status || "Unknown";
        const year = this.model.year || this.model.aired?.from?.split('-')[0] || "?";

        let body = `### ${isEpisode ? '📺 Episode Discussion' : '💬 General Discussion'}\n\n`;
        body += `![${this.model.title}|690x388](${imageUrl})\n\n`;
        body += `**[View on Anime Database](${animeUrl})**\n\n`;
        body += `| | |\n|---|---|\n`;
        body += `| **Score** | ⭐ ${score} |\n`;
        body += `| **Episodes** | ${totalEpisodes} |\n`;
        body += `| **Status** | ${status} |\n`;
        body += `| **Year** | ${year} |\n`;
        body += `| **Type** | ${this.model.type || "?"} |\n\n`;
        body += `---\n\n`;
        body += isEpisode
            ? 'Share your thoughts about the episodes!'
            : 'What do you think about this anime?';

        return body;
    }
}
