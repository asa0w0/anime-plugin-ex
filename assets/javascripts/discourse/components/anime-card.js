import Component from "@glimmer/component";
import { service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AnimeCard extends Component {
  @service router;
  @service currentUser;
  @tracked isAdding = false;
  @tracked showStatusMenu = false;

  get typeLabel() {
    const type = this.args.anime.type;
    if (!type) return null;

    const labels = {
      'TV': 'TV',
      'Movie': 'Movie',
      'OVA': 'OVA',
      'Special': 'Special',
      'ONA': 'ONA'
    };
    return labels[type] || type;
  }

  get episodeCount() {
    const eps = this.args.anime.episodes;
    if (!eps) return null;
    return eps === 1 ? '1 ep' : `${eps} eps`;
  }

  get topGenres() {
    const genres = this.args.anime.genres;
    if (!genres || genres.length === 0) return [];
    // Return top 3 genres
    return genres.slice(0, 3).map(g => g.name);
  }

  get animeScore() {
    const score = this.args.anime.score;
    // explicit check for null/undefined to allow 0
    return (score !== null && score !== undefined) ? score : "N/A";
  }

  get isOnWatchlist() {
    if (!this.currentUser || !this.args.watchlistData) return false;
    const malId = this.args.anime.mal_id?.toString();
    // Check if key exists (status can be anything, as long as it exists)
    return Object.prototype.hasOwnProperty.call(this.args.watchlistData, malId);
  }

  get currentStatus() {
    if (!this.currentUser || !this.args.watchlistData) return null;
    const malId = this.args.anime.mal_id?.toString();
    return this.args.watchlistData[malId];
  }

  get isMenuOpen() {
    if (this.args.activeAnimeId !== undefined) {
      return this.args.activeAnimeId === this.args.anime.mal_id;
    }
    return this.showStatusMenu;
  }

  @action
  toggleStatusMenu(event) {
    event.preventDefault();
    event.stopPropagation();

    if (!this.currentUser) {
      this.router.transitionTo("login");
      return;
    }

    if (this.args.onToggleMenu) {
      this.args.onToggleMenu(this.args.anime.mal_id);
    } else {
      this.showStatusMenu = !this.showStatusMenu;

      // Close menu when clicking anywhere else on the page
      if (this.showStatusMenu) {
        this.documentClickHandler = (e) => {
          if (!e.target.closest('.anime-card-quick-add-container')) {
            this.showStatusMenu = false;
            document.removeEventListener('click', this.documentClickHandler);
          }
        };
        // Use setTimeout to avoid immediate triggering
        setTimeout(() => {
          document.addEventListener('click', this.documentClickHandler);
        }, 0);
      }
    }
  }

  willDestroy() {
    super.willDestroy();
    if (this.documentClickHandler) {
      document.removeEventListener('click', this.documentClickHandler);
    }
  }

  @action
  async selectStatus(status, event) {
    event.preventDefault();
    event.stopPropagation();

    // this.showStatusMenu = false; // Kept open by user request

    if (this.isAdding) {
      return;
    }
    this.isAdding = true;

    try {
      if (status === "remove") {
        await ajax(`/anime/watchlist/${this.args.anime.mal_id}`, {
          type: "DELETE",
        });
      } else {
        await ajax("/anime/watchlist", {
          type: "POST",
          data: {
            anime_id: this.args.anime.mal_id,
            status: status,
            title: this.args.anime.title,
            image_url: this.args.anime.images?.jpg?.image_url,
          },
        });
      }

      if (this.args.onWatchlistUpdate) {
        this.args.onWatchlistUpdate();
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isAdding = false;
    }
  }

  @action
  addToWatchlist(event) {
    this.toggleStatusMenu(event);
  }
}
