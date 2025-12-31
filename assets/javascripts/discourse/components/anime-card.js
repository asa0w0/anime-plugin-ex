import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class AnimeCard extends Component {
  @service router;
  @service currentUser;

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
    // TODO: Check if anime is on user's watchlist
    // This will need to be implemented with watchlist state management
    return false;
  }

  @action
  async addToWatchlist(event) {
    event.preventDefault();
    event.stopPropagation();
    
    if (!this.currentUser) {
      this.router.transitionTo('login');
      return;
    }

    // TODO: Implement quick-add to watchlist
    // This will open a dropdown to select status (watching, completed, etc.)
    console.log('Add to watchlist:', this.args.anime.title);
  }
}
