import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import RSVP from "rsvp";

export default class ShowRoute extends Route {
    async model(params) {
        const animeId = params.id;

        const promises = {
            anime: ajax(`/anime/${animeId}`).then((data) => data.data),
            episodes: ajax(`/anime/${animeId}/episodes`).catch(() => ({ episodes: [] }))
        };

        const results = await RSVP.hash(promises);
        const animeData = results.anime || {};

        return {
            ...animeData,
            episodeDiscussions: results.episodes?.episodes || [],
            streaming: results.episodes?.streaming || []
        };
    }

    setupController(controller, model) {
        super.setupController(controller, model);
        // Reset episode pagination when switching anime
        controller.set("episodePage", 1);
    }
}
