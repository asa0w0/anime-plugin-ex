import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class IndexRoute extends Route {
    model() {
        return ajax("/anime").then((data) => data.data);
    }
}
