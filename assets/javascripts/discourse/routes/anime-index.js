import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default Route.extend({
    model() {
        return ajax("/anime-api/list").then(data => data.data);
    }
});
