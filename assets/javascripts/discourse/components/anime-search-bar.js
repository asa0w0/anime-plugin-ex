import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class AnimeSearchBar extends Component {
    @tracked localValue = "";

    constructor() {
        super(...arguments);
        this.localValue = this.args.value || "";
    }

    @action
    onInput(event) {
        this.localValue = event.target.value;
    }

    @action
    onKeyPress(event) {
        if (event.key === "Enter") {
            this.triggerSearch();
        }
    }

    @action
    onBlur() {
        // Only search on blur if value changed
        if (this.localValue !== this.args.value) {
            this.triggerSearch();
        }
    }

    triggerSearch() {
        if (this.args.onChange) {
            this.args.onChange(this.localValue);
        }
    }

    @action
    clearSearch() {
        this.localValue = "";
        if (this.args.onChange) {
            this.args.onChange("");
        }
    }
}
