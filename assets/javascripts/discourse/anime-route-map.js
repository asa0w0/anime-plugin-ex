export default function () {
    this.route("anime", function () {
        this.route("show", { path: "/:id" });
    });
}
