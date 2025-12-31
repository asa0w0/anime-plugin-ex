import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class CalendarRoute extends Route {
    model() {
        return ajax("/anime/calendar");
    }
}
