import { withPluginApi } from "discourse/lib/plugin-api";

export default {
    name: "anime-database",
    initialize() {
        withPluginApi("1.34.0", (api) => {
            api.serializeOnCreate("anime_mal_id");
            api.serializeOnCreate("anime_episode_number");

            api.modifyClass("model:composer", {
                pluginId: "anime-plugin-ex",

                open(opts) {
                    // Support both direct opts and nested topicCustomFields
                    const malId = opts.anime_mal_id || opts.topicCustomFields?.anime_mal_id;
                    const epNum = opts.anime_episode_number || opts.topicCustomFields?.anime_episode_number;

                    if (malId) {
                        this.set("anime_mal_id", malId);
                    }
                    if (epNum) {
                        this.set("anime_episode_number", epNum);
                    }
                    return this._super(...arguments);
                }
            });
        });
    },
};
