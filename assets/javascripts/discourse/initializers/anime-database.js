import { withPluginApi } from "discourse/lib/plugin-api";

export default {
    name: "anime-database",
    initialize() {
        withPluginApi("1.34.0", (api) => {
            api.serializeOnCreate("anime_mal_id");

            api.addRouteMap(function () {
                this.route("user", { path: "/u/:username", resetNamespace: true }, function () {
                    this.route("watchlist");
                });
            });

            api.renderInOutlet("user-main-nav", "user-watchlist-nav");

            api.modifyClass("model:composer", {
                pluginId: "anime-plugin-ex",

                open(opts) {
                    if (opts.anime_mal_id) {
                        this.set("anime_mal_id", opts.anime_mal_id);
                    }
                    return this._super(...arguments);
                }
            });
        });
    },
};
