import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class AnimeSearchBar extends Component {
    @tracked timer = null;

    @action
    onInput(event) {
        if (this.timer) {
            clearTimeout(this.timer);
        }

        this.timer = setTimeout(() => {
            if (this.args.onChange) {
                this.args.onChange(event.target.value);
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
