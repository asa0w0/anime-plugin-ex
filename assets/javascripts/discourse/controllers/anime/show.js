import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default Controller.extend({
    composer: service(),

    actions: {
        createDiscussion() {
            this.composer.open({
                action: "createTopic",
                title: `Discussion: ${this.model.title}`,
                category: this.siteSettings.anime_database_category,
                topicCustomFields: { anime_mal_id: this.model.mal_id.toString() },
                importQuote: `Discussing ${this.model.title}\n\n[quote]\n${this.model.synopsis}\n[/quote]`
            });
        }
    }
});
