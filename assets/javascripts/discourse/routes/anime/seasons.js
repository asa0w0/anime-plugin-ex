import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class SeasonsRoute extends Route {
    model(params) {
        let url = "/anime/seasons";
        if (params.year && params.season) {
            url = `/anime/seasons/${params.year}/${params.season}`;
        }
        return ajax(url);
    }
}
