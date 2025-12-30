import Component from "@glimmer/component";

export default class WatchlistNav extends Component {
    get user() {
        return this.args.outletArgs.model;
    }
}
