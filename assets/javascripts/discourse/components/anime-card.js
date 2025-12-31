import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AnimeCard extends Component {
  @service router;
  @service currentUser;
  @tracked isAdding = false;

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
    return this.args.anime.score || "N/A";
  }

  get isOnWatchlist() {
    if (!this.currentUser || !this.args.watchlistIds) return false;
    const malId = this.args.anime.mal_id?.toString();
    return this.args.watchlistIds.includes(malId);
  }

  @action
  async addToWatchlist(event) {
    event.preventDefault();
    event.stopPropagation();

    if (!this.currentUser) {
      this.router.transitionTo('login');
      return;
    }

    if (this.isAdding) return;
    this.isAdding = true;

    try {
      await ajax("/anime/update_watchlist", {
        type: "POST",
        data: {
          anime_id: this.args.anime.mal_id,
          status: "watching",
          title: this.args.anime.title,
          image_url: this.args.anime.images?.jpg?.image_url
        }
      });

      // Refresh watchlist IDs by calling the parent controller action
      if (this.args.onWatchlistUpdate) {
        this.args.onWatchlistUpdate();
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isAdding = false;
    }
  }
}
