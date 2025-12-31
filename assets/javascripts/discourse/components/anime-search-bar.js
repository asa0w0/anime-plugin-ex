import Component from "@glimmer/component";
import { action } from "@ember/object";
import { restartableTask } from "ember-concurrency";
import { timeout } from "ember-concurrency";

export default class AnimeSearchBar extends Component {
    @restartableTask
    *debounceSearch(query) {
        yield timeout(500);
        this.args.onChange(query);
    }

    @action
    onInput(event) {
        this.debounceSearch.perform(event.target.value);
    }

    @action
    clearSearch() {
        this.debounceSearch.cancelAll();
        this.args.onChange("");
    }
}
