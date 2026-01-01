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

        return {
            ...results.anime,
            episodeDiscussions: results.episodes.episodes || []
        };
    }
}
