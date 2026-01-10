import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class AnimeSearchBar extends Component {
    @tracked timer = null;

    @action
    onInput(event) {
        const value = event.target.value;
        this.debounceSearch(value);
    }

    @action
    onKeyPress(event) {
        if (event.key === "Enter") {
            if (this.timer) {
                clearTimeout(this.timer);
            }
            if (this.args.onChange) {
                this.args.onChange(event.target.value);
            }
        }
    }

    debounceSearch(value) {
        if (this.timer) {
            clearTimeout(this.timer);
        }

        // Don't search for very short queries (except empty to clear)
        if (value.length > 0 && value.length < 2) {
            return;
        }

        this.timer = setTimeout(() => {
            if (this.args.onChange) {
                this.args.onChange(value);
            }
        }, 1500); // 1.5 seconds - plenty of time to type
    }

    @action
    clearSearch() {
        if (this.timer) {
            clearTimeout(this.timer);
        }
        if (this.args.onChange) {
            this.args.onChange("");
        }
    }
}
