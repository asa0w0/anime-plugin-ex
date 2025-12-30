import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class UserWatchlistRoute extends Route {
    model() {
        const username = this.modelFor("user").username;
        return ajax(`/anime/watchlist/${username}`).then((data) => {
            if (data.data && Array.isArray(data.data.data)) {
                return data.data.data;
            }
            return data.data || [];
        });
    }
}
