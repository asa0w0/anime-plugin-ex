import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class ShowRoute extends Route {
    model(params) {
        return ajax(`/anime/${params.id}`).then((data) => data.data);
    }
}
