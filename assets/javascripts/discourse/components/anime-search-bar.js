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

        this.timer = setTimeout(() => {
            if (this.args.onChange) {
                this.args.onChange(value);
            }
        }, 500);
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
