import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class WatchlistController extends Controller {
    @tracked searchTerm = "";
    @tracked activeFilter = "all";
    @tracked editMode = false;
    @tracked selectedIds = new Set();
    @tracked selectionTrigger = 0; // Trigger for reactivity

    // Swipe state
    startX = 0;
    currentX = 0;
    activeSwipeId = null;

    @action
    handleTouchStart(animeId, event) {
        if (this.editMode) return;
        this.startX = event.touches[0].clientX;
        this.activeSwipeId = animeId;
    }

    @action
    handleTouchMove(event) {
        if (!this.activeSwipeId || this.editMode) return;
        this.currentX = event.touches[0].clientX;
        const diff = this.currentX - this.startX;

        // Find the element and apply transform for visual feedback
        const el = document.querySelector(`[data-anime-id="${this.activeSwipeId}"] .item-content-wrapper`);
        if (el) {
            // Limit swipe distance
            const translate = Math.max(Math.min(diff, 100), -100);
            el.style.transform = `translateX(${translate}px)`;

            // Show background layers based on direction
            const parent = el.parentElement;
            if (diff > 20) {
                parent.classList.add('swiping-right');
                parent.classList.remove('swiping-left');
            } else if (diff < -20) {
                parent.classList.add('swiping-left');
                parent.classList.remove('swiping-right');
            } else {
                parent.classList.remove('swiping-left', 'swiping-right');
            }
        }
    }

    @action
    handleTouchEnd(animeId, event) {
        if (!this.activeSwipeId || this.editMode) return;

        const diff = this.currentX - this.startX;
        const el = document.querySelector(`[data-anime-id="${this.activeSwipeId}"] .item-content-wrapper`);

        if (el) {
            el.style.transform = '';
            el.parentElement.classList.remove('swiping-left', 'swiping-right');
        }

        if (diff > 80) {
            // Swipe Right -> Complete
            this.setStatusDirectly(animeId, 'completed');
        } else if (diff < -80) {
            // Swipe Left -> Delete
            this.removeFromWatchlist(animeId);
        }

        this.activeSwipeId = null;
        this.startX = 0;
        this.currentX = 0;
    }

    vibrate(duration = 10) {
        if ("vibrate" in navigator) {
            navigator.vibrate(duration);
        }
    }

    get filteredModel() {
        const term = (this.searchTerm || "").trim().toLowerCase();
        const items = this.model || [];

        if (!term) {
            return items;
        }

        return items.filter(item => {
            const title = (item.title || "").toLowerCase();
            return title.includes(term);
        });
    }

    get watching() {
        return this.filteredModel.filter(item => item.status === "watching");
    }

    get planned() {
        return this.filteredModel.filter(item => item.status === "plan_to_watch");
    }

    get completed() {
        return this.filteredModel.filter(item => item.status === "completed");
    }

    get onHold() {
        return this.filteredModel.filter(item => item.status === "on_hold");
    }

    get dropped() {
        return this.filteredModel.filter(item => item.status === "dropped");
    }

    @action
    setSearchTerm(event) {
        this.set("searchTerm", event.target.value);
    }

    @action
    clearSearch() {
        this.vibrate(5);
        this.set("searchTerm", "");
    }

    @action
    setActiveFilter(filter) {
        this.vibrate(5);
        this.set("activeFilter", filter);
    }

    @action
    isItemSelected(animeId) {
        this.selectionTrigger;
        return this.selectedIds.has(animeId);
    }

    @action
    toggleEditMode() {
        this.vibrate(5);
        this.set("editMode", !this.editMode);
        if (!this.editMode) {
            this.selectedIds.clear();
            this.set("selectionTrigger", this.selectionTrigger + 1);
        }
    }

    @action
    toggleSelection(animeId) {
        this.vibrate(5);
        if (this.selectedIds.has(animeId)) {
            this.selectedIds.delete(animeId);
        } else {
            this.selectedIds.add(animeId);
        }
        this.set("selectionTrigger", this.selectionTrigger + 1);
    }

    get isAllSelected() {
        this.selectionTrigger;
        return (this.model || []).length > 0 && this.selectedIds.size === (this.model || []).length;
    }

    @action
    toggleSelectAll() {
        this.vibrate(5);
        if (this.isAllSelected) {
            this.selectedIds.clear();
        } else {
            (this.model || []).forEach(item => this.selectedIds.add(item.anime_id));
        }
        this.set("selectionTrigger", this.selectionTrigger + 1);
    }

    @action
    async bulkDelete() {
        if (this.selectedIds.size === 0) return;

        this.vibrate(10);
        if (!confirm(`Remove ${this.selectedIds.size} items from your watchlist?`)) return;

        const idsToRemove = Array.from(this.selectedIds);
        try {
            await Promise.all(idsToRemove.map(id => ajax(`/anime/watchlist/${id}`, { type: "DELETE" })));
            const newModel = (this.model || []).filter(item => !this.selectedIds.has(item.anime_id));
            this.set("model", newModel);
            this.selectedIds.clear();
            this.set("editMode", false);
            this.vibrate([10, 50, 10]);
        } catch (error) {
            console.error("Bulk delete error:", error);
        }
    }

    @action
    async bulkChangeStatus(status) {
        if (this.selectedIds.size === 0) return;

        this.vibrate(10);
        const idsToUpdate = Array.from(this.selectedIds);
        try {
            await Promise.all(idsToUpdate.map(id => {
                const item = this.model.find(i => i.anime_id === id);
                return ajax("/anime/watchlist", {
                    type: "POST",
                    data: {
                        anime_id: id,
                        status: status,
                        title: item.title,
                        image_url: item.image_url
                    }
                });
            }));

            // Refresh model or update locally
            const newModel = this.model.map(item => {
                if (this.selectedIds.has(item.anime_id)) {
                    return { ...item, status };
                }
                return item;
            });
            this.set("model", newModel);
            this.selectedIds.clear();
            this.set("editMode", false);
            this.vibrate([10, 50, 10]);
        } catch (error) {
            console.error("Bulk update error:", error);
        }
    }

    @action
    async setStatusDirectly(animeId, status) {
        const item = this.model.find(i => i.anime_id === animeId);
        if (!item) return;

        try {
            await ajax("/anime/watchlist", {
                type: "POST",
                data: {
                    anime_id: animeId,
                    status: status,
                    title: item.title,
                    image_url: item.image_url
                }
            });
            const newModel = this.model.map(i => i.anime_id === animeId ? { ...i, status } : i);
            this.set("model", newModel);
            this.vibrate([10, 50, 10]);
        } catch (error) {
            console.error("Direct status update error:", error);
        }
    }

    @action
    async removeFromWatchlist(animeId) {
        this.vibrate(15);
        try {
            await ajax(`/anime/watchlist/${animeId}`, { type: "DELETE" });
            const newModel = (this.model || []).filter(item => item.anime_id !== animeId);
            this.set("model", newModel);
            this.vibrate([10, 50, 10]); // Success pattern
        } catch (error) {
            console.error("Error removing from watchlist:", error);
        }
    }
}
