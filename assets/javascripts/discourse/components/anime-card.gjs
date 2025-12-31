import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { or } from "truth-helpers";
import { on } from "@ember/modifier";
import { d-icon } from "discourse/lib/icon-library";

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

  <template>
    <div class="anime-card-enhanced">
      <LinkTo @route="anime.show" @model={{@anime.mal_id}} class="anime-card-link">
        <div class="anime-card-image">
          <img src={{@anime.images.jpg.image_url}} alt={{@anime.title}} loading="lazy" />
          <div class="anime-card-rating">
            <span class="score">⭐ {{or @anime.score "N/A"}}</span>
          </div>
        </div>
        <div class="anime-card-content">
          <h3 class="anime-card-title">{{@anime.title}}</h3>
          
          {{#if this.typeLabel}}
          <div class="anime-card-meta">
            <span class="meta-type">{{this.typeLabel}}</span>
            {{#if this.episodeCount}}
            <span class="meta-separator">•</span>
            <span class="meta-episodes">{{this.episodeCount}}</span>
            {{/if}}
          </div>
          {{/if}}

          {{#if this.topGenres.length}}
          <div class="anime-card-genres">
            {{#each this.topGenres as |genre|}}
            <span class="genre-tag">{{genre}}</span>
            {{/each}}
          </div>
          {{/if}}
        </div>
      </LinkTo>
      
      {{#if this.currentUser}}
      <button 
        type="button" 
        class="anime-card-quick-add {{if this.isOnWatchlist 'on-watchlist'}}"
        {{on "click" this.addToWatchlist}}
        title="Add to Watchlist">
        {{d-icon (if this.isOnWatchlist "heart" "heart")}}
      </button>
      {{/if}}
    </div>
  </template>
}
