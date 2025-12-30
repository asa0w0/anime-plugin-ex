export default function () {
    this.route("anime", { path: "/anime" }, function () {
        this.route("watchlist", { path: "/watchlist" });
        this.route("seasons", { path: "/seasons(/:year/:season)" });
        this.route("show", { path: "/:id" });
    });
    this.route("user", { path: "/u/:username", resetNamespace: true }, function () {
        this.route("watchlist");
    });
}
