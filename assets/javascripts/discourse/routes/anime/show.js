import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default Route.extend({
    model(params) {
        return ajax(`/anime-api/details/${params.id}`).then(data => data.data);
    }
});
