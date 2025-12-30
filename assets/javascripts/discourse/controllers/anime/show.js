import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ShowController extends Controller {
    @service composer;
    @service siteSettings;

    @action
    createDiscussion() {
        this.composer.open({
            action: "createTopic",
            title: `Discussion: ${this.model.title}`,
            categoryId: this.siteSettings.anime_database_category,
            topicCustomFields: { anime_mal_id: this.model.mal_id.toString() },
            importQuote: `Discussing ${this.model.title}\n\n[quote]\n${this.model.synopsis}\n[/quote]`,
        });
    }
}
