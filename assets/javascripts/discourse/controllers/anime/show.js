import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ShowController extends Controller {
    @service composer;
    @service("site-settings") siteSettings;

    @action
    createDiscussion(type = "general") {
        const categoryId = parseInt(this.siteSettings.anime_database_category, 10);
        const isEpisode = type === "episodes";

        const title = isEpisode
            ? `Episodes Discussion: ${this.model.title}`
            : `Discussion: ${this.model.title}`;

        const draftKey = `anime-${type}-${this.model.mal_id}`;

        this.composer.open({
            action: "createTopic",
            draftKey: draftKey,
            topicTitle: title,
            topicCategoryId: categoryId > 0 ? categoryId : null,
            topicBody: `Discussing ${this.model.title}\n\n[quote]\n${this.model.synopsis}\n[/quote]`,
            anime_mal_id: this.model.mal_id.toString(),
        });
    }
}
