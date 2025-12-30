import { withPluginApi } from "discourse/lib/plugin-api";

export default {
    name: "anime-database",
    initialize() {
        withPluginApi("1.34.0", (api) => {
            api.serializeOnCreate("anime_mal_id");
        });
    },
};
