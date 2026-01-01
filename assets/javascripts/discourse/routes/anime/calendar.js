import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import applyCalendarStyles from "../lib/anime-calendar-styles";

export default class CalendarRoute extends Route {
    model() {
        return ajax("/anime/calendar");
    }

    activate() {
        super.activate(...arguments);
        applyCalendarStyles();
    }
}
