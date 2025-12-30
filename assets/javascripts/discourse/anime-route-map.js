export default function () {
    this.route("anime", function () {
        this.route("show", { path: "/:id" });
        this.route("watchlist", { path: "/watchlist" });
    });
    this.route("user", { path: "/u/:username", resetNamespace: true }, function () {
        this.route("watchlist", { path: "/watchlist" });
    });
}
