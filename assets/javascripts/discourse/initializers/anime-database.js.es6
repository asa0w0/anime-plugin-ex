import { withPluginApi } from "discourse/lib/plugin-api";

export default {
    name: "anime-database",
    initialize() {
        withPluginApi("0.8", (api) => {
            api.addRoute("anime.index", { path: "/anime" });
            api.addRoute("anime.show", { path: "/anime/:id" });
        });
    },
};
