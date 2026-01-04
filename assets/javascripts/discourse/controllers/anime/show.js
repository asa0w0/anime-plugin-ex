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
    @tracked episodePage = 1;
    @tracked activeVideo = null; // For video modal
    @tracked synopsisExpanded = false; // For collapsible synopsis
    @tracked fabMenuOpen = false; // For FAB status menu
    @tracked saving = false; // For loading spinner
    @tracked addedToWatchlist = false; // For success feedback

    get backdropUrl() {
        if (this.model?.tmdb?.backdrop_path) {
            return `https://image.tmdb.org/t/p/original${this.model.tmdb.backdrop_path}`;
        }
        return null;
    }

    slugify(text) {
        if (!text) return "";
        return text
            .toString()
            .toLowerCase()
            .trim()
            .replace(/\s+/g, "-")
            .replace(/[^\w-]+/g, "")
            .replace(/--+/g, "-");
    }

    get episodesPerPage() {
        return 13;
    }

    get totalEpisodePages() {
        const episodes = this.model?.episodeDiscussions || [];
        return Math.ceil(episodes.length / this.episodesPerPage);
    }

    get scoreColorClass() {
        const score = parseFloat(this.model?.score);
        if (isNaN(score)) return "unknown";
        if (score >= 8.0) return "high";
        if (score >= 6.0) return "medium";
        return "low";
    }

    get paginatedEpisodes() {
        const episodes = this.enhancedEpisodes || [];
        const start = (this.episodePage - 1) * this.episodesPerPage;
        return episodes.slice(start, start + this.episodesPerPage);
    }

    safeGetHostname(url) {
        if (!url || typeof url !== "string") return "";
        try {
            const absoluteUrl = url.startsWith("http") ? url : `https://${url}`;
            return new URL(absoluteUrl).hostname;
        } catch (e) {
            return "";
        }
    }

    get enhancedEpisodes() {
        const episodes = this.model?.episodeDiscussions || [];
        const anilistStreaming = this.model?.anilist?.streaming || [];
        const jikanStreaming = this.model?.streaming || []; // General series links from Jikan

        return episodes.map((ep) => {
            const providers = new Map();

            // 1. Process Jikan series links as base providers
            jikanStreaming.forEach((s) => {
                if (!s || !s.url) return;
                const domain = this.safeGetHostname(s.url);
                providers.set(s.name, {
                    site: s.name,
                    url: s.url,
                    faviconUrl: domain ? `https://www.google.com/s2/favicons?domain=${domain}&sz=32` : null,
                    type: "series"
                });
            });

            // 2. Process AniList deep links and override/add
            anilistStreaming.forEach((s) => {
                if (!s || !s.url) return;

                // Robust episode number extraction
                let epNum = null;
                const title = s.title || "";

                // Try specific patterns first
                const patterns = [
                    /Episode\s+(\d+)/i,
                    /Ep\.\s*(\d+)/i,
                    /EP\s+(\d+)/i,
                    /-\s*(\d+)\s*$/ // Trailing number e.g. "Re:Zero S3 - 01"
                ];

                for (const regex of patterns) {
                    const match = title.match(regex);
                    if (match) {
                        epNum = parseInt(match[1], 10);
                        break;
                    }
                }

                // If no specific pattern matched, try any single number in title
                if (epNum === null) {
                    const match = title.match(/(\d+)/);
                    if (match) {
                        epNum = parseInt(match[1], 10);
                    }
                }

                if (epNum === ep.episode_number) {
                    const domain = this.safeGetHostname(s.url);
                    // Prefer deep links over series links for matched episodes
                    providers.set(s.site, {
                        site: s.site,
                        url: s.url,
                        faviconUrl: domain ? `https://www.google.com/s2/favicons?domain=${domain}&sz=32` : null,
                        type: "episode"
                    });
                }
            });

            return {
                ...ep,
                streamingProviders: Array.from(providers.values())
            };
        });
    }

    get watchlistStatus() {
        if (this._manualStatus) return this._manualStatus;
        const ws = this.model?.watchlist_status;
        // Handle both string and object format
        return typeof ws === 'object' ? ws?.status : ws;
    }

    get displayWatchlistStatus() {
        const status = this.watchlistStatus;
        if (!status || typeof status !== 'string') {
            return "";
        }
        const labels = {
            watching: "Watching",
            completed: "Completed",
            plan_to_watch: "Plan to Watch",
            on_hold: "On Hold",
            dropped: "Dropped"
        };
        return labels[status] || (status.charAt(0).toUpperCase() + status.slice(1));
    }

    @action
    changeStatus(event) {
        this.selectedStatus = event.target.value;
    }

    @action
    async saveToWatchlist() {
        if (!this.currentUser || !this.selectedStatus || this.saving) {
            return;
        }

        this.saving = true;
        try {
            await ajax("/anime/watchlist", {
                type: "POST",
                data: {
                    anime_id: this.model.mal_id,
                    status: this.selectedStatus,
                    title: this.model.title,
                    image_url: this.model.images?.jpg?.image_url || this.model.image_url,
                    episodes_watched: 0,
                    total_episodes: this.model.episodes || 0,
                }
            });
            this._manualStatus = this.selectedStatus;
            this.selectedStatus = null;
            this.addedToWatchlist = true;

            // Show success for 3 seconds
            setTimeout(() => {
                this.addedToWatchlist = false;
            }, 3000);
        } catch (error) {
            console.error("Error updating watchlist:", error);
        } finally {
            this.saving = false;
        }
    }

    @action
    createDiscussion(type = "general", episode = null) {
        if (!this.model) {
            return;
        }

        // In Ember, if called via {{on "click"}}, the last argument is the event.
        // We need to ensure we only treat 'episode' as such if it's an actual episode object.
        const isActualEpisode = episode && typeof episode === 'object' && episode.episode_number !== undefined;
        const targetEpisode = isActualEpisode ? episode : null;

        // Use the appropriate category based on discussion type
        let categoryId;
        if (targetEpisode) {
            // Episode discussions use anime_episode_category
            categoryId = parseInt(this.siteSettings.anime_episode_category, 10);
        } else {
            // General discussions use anime_database_category
            categoryId = parseInt(this.siteSettings.anime_database_category, 10);
        }

        const isEpisodeType = type === "episodes";

        let title, body;

        if (targetEpisode) {
            // Episode-specific discussion
            title = `[Anime] ${this.model.title} - Episode ${targetEpisode.episode_number} Discussion`;
            body = this.buildEpisodeBody(targetEpisode);
        } else {
            // General discussion
            title = isEpisodeType
                ? `Episodes Discussion: ${this.model.title}`
                : `Discussion: ${this.model.title}`;
            body = this.buildGeneralBody(isEpisodeType);
        }

        const draftKey = targetEpisode
            ? `anime-episode-${this.model.mal_id}-${targetEpisode.episode_number}`
            : `anime-${type}-${this.model.mal_id}`;

        const animeTag = this.model.title ? this.slugify(this.model.title) : "";
        const malIdString = this.model.mal_id ? this.model.mal_id.toString() : "";
        const episodeNumString = targetEpisode ? targetEpisode.episode_number.toString() : null;

        const composerOpts = {
            action: "createTopic",
            draftKey: draftKey,
            topicTitle: title,
            topicCategoryId: categoryId > 0 ? categoryId : null,
            topicBody: body,
            tags: [animeTag],
            topicCustomFields: {
                anime_mal_id: malIdString,
                anime_episode_number: episodeNumString
            }
        };

        this.composer.open(composerOpts);
    }

    buildEpisodeBody(episode) {
        const animeUrl = `${window.location.origin}/anime/${this.model.slug || this.model.mal_id}`;
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
        const animeUrl = `${window.location.origin}/anime/${this.model.slug || this.model.mal_id}`;
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

    @action
    playVideo(video) {
        this.activeVideo = video;
    }

    @action
    closeVideo() {
        this.activeVideo = null;
    }

    @action
    stopClick(event) {
        event.stopPropagation();
    }

    @action
    nextEpisodePage() {
        if (this.episodePage < this.totalEpisodePages) {
            this.episodePage++;
            // Scroll to top of episodes section
            document.querySelector('.anime-episodes-section')?.scrollIntoView({ behavior: 'smooth' });
        }
    }

    @action
    prevEpisodePage() {
        if (this.episodePage > 1) {
            this.episodePage--;
            document.querySelector('.anime-episodes-section')?.scrollIntoView({ behavior: 'smooth' });
        }
    }

    @action
    toggleSynopsis() {
        this.synopsisExpanded = !this.synopsisExpanded;
    }

    @action
    scrollToSection(sectionId) {
        const element = document.getElementById(sectionId);
        if (element) {
            element.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    vibrate(duration = 10) {
        if ("vibrate" in navigator) {
            navigator.vibrate(duration);
        }
    }

    @action
    async quickAddToWatchlist() {
        this.vibrate(5);
        this.fabMenuOpen = !this.fabMenuOpen;
    }

    @action
    async setStatusFromFab(status) {
        this.vibrate(15);
        if (!this.currentUser) {
            return;
        }

        try {
            const response = await ajax("/anime/watchlist", {
                type: "POST",
                data: {
                    anime_id: this.model.mal_id,
                    status: status,
                    title: this.model.title,
                    image_url: this.model.images?.jpg?.image_url || "",
                    episodes_watched: 0,
                    total_episodes: this.model.episodes || 0,
                }
            });

            if (response.success) {
                this._manualStatus = status;
                this.fabMenuOpen = false;
                this.vibrate([10, 50, 10]); // Success pattern
            } else {
                console.error("Watchlist error:", response);
                alert(response.error || "Failed to update watchlist");
            }
        } catch (error) {
            console.error("Error updating watchlist:", error);
            if (error.jqXHR?.responseJSON?.error) {
                alert(error.jqXHR.responseJSON.error);
            }
        }
    }


    @action
    closeFabMenu() {
        this.vibrate(5);
        this.fabMenuOpen = false;
    }
}

