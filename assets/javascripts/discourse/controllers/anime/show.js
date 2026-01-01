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
    createDiscussion(type = "general", episode = null) {
        // Use the appropriate category based on discussion type
        let categoryId;
        if (episode) {
            // Episode discussions use anime_episode_category
            categoryId = parseInt(this.siteSettings.anime_episode_category, 10);
        } else {
            // General discussions use anime_database_category
            categoryId = parseInt(this.siteSettings.anime_database_category, 10);
        }

        const isEpisode = type === "episodes";

        let title, body;

        if (episode) {
            // Episode-specific discussion
            title = `[Anime] ${this.model.title} - Episode ${episode.episode_number} Discussion`;
            body = this.buildEpisodeBody(episode);
        } else {
            // General discussion
            title = isEpisode
                ? `Episodes Discussion: ${this.model.title}`
                : `Discussion: ${this.model.title}`;
            body = this.buildGeneralBody(isEpisode);
        }

        const draftKey = episode
            ? `anime-episode-${this.model.mal_id}-${episode.episode_number}`
            : `anime-${type}-${this.model.mal_id}`;

        const composerOpts = {
            action: "createTopic",
            draftKey: draftKey,
            topicTitle: title,
            topicCategoryId: categoryId > 0 ? categoryId : null,
            topicBody: body,
        };

        // Add custom fields for linking
        if (episode) {
            composerOpts.tags = [`anime-${this.model.mal_id}`, `episode-${episode.episode_number}`];
            // Store metadata for the topic_created hook
            composerOpts.anime_mal_id = this.model.mal_id.toString();
            composerOpts.anime_episode_number = episode.episode_number.toString();
        } else {
            composerOpts.tags = [`anime-${this.model.mal_id}`];
            composerOpts.anime_mal_id = this.model.mal_id.toString();
        }

        this.composer.open(composerOpts);
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
