import Component from "@glimmer/component";

export default class UserWatchlistNav extends Component {
    get user() {
        return this.args.outletArgs.model;
    }
}
