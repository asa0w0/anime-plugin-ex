import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";

export default class AnimeCard extends Component {
  <template>
    <LinkTo @route="anime.show" @model={{@anime.mal_id}} class="anime-card-link">
      <div class="anime-card">
        <div class="anime-card-image">
          <img src={{@anime.images.jpg.image_url}} alt={{@anime.title}} loading="lazy" />
          <div class="anime-card-rating">
            <span class="score">{{@anime.score}}</span>
          </div>
        </div>
        <div class="anime-card-content">
          <h3 class="anime-card-title">{{@anime.title}}</h3>
        </div>
      </div>
    </LinkTo>
  </template>
}
