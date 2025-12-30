import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ShowController extends Controller {
    @service composer;
    @service("site-settings") siteSettings;

    @action
    createDiscussion() {
        const categoryId = parseInt(this.siteSettings.anime_database_category, 10);

        this.composer.open({
            action: "createTopic",
            draftKey: "anime-new-discussion",
            topicTitle: `Discussion: ${this.model.title}`,
            topicCategoryId: categoryId > 0 ? categoryId : null,
            topicBody: `Discussing ${this.model.title}\n\n[quote]\n${this.model.synopsis}\n[/quote]`,
            topicCustomFields: { anime_mal_id: this.model.mal_id.toString() },
        });
    }
}
