import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class WatchlistRoute extends Route {
    model() {
        return ajax("/anime/watchlist").then((data) => {
            if (data.data && Array.isArray(data.data.data)) {
                return data.data.data;
            }
            return data.data || [];
        });
    }
}
