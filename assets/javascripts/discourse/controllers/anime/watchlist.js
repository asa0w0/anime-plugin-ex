import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { later, cancel } from "@ember/runloop";

export default class WatchlistController extends Controller {
    @tracked searchTerm = "";
    @tracked activeFilter = "all";
    @tracked editMode = false;
    @tracked selectedIds = new Set();
    @tracked selectionTrigger = 0;
    @tracked isLoading = false;
    @tracked openDropdownId = null;
    @tracked sortColumn = "title";
    @tracked sortDirection = "asc";

    // Swipe state (non-tracked for performance)
    _startX = 0;
    _currentX = 0;
    _activeSwipeId = null;
    _activeElement = null;
    _searchDebounceTimer = null;

    // Vibration helper
    vibrate(duration = 10) {
        if ("vibrate" in navigator) {
            try {
                navigator.vibrate(duration);
            } catch (e) {
                // Ignore vibration errors on unsupported devices
            }
        }
    }

    // Debounced search
    @action
    setSearchTerm(event) {
        const value = event.target.value;

        // Cancel previous debounce timer
        if (this._searchDebounceTimer) {
            cancel(this._searchDebounceTimer);
        }

        // Debounce 300ms for performance
        this._searchDebounceTimer = later(this, () => {
            this.searchTerm = value;
        }, 300);
    }

    @action
    clearSearch() {
        this.vibrate(5);
        if (this._searchDebounceTimer) {
            cancel(this._searchDebounceTimer);
        }
        this.searchTerm = "";
    }

    // Touch handlers with cached element references
    @action
    handleTouchStart(animeId, event) {
        if (this.editMode) return;

        this._startX = event.touches[0].clientX;
        this._activeSwipeId = animeId;

        // Cache the element reference immediately
        const target = event.currentTarget;
        this._activeElement = target;
    }

    @action
    handleTouchMove(event) {
        if (!this._activeSwipeId || this.editMode || !this._activeElement) return;

        this._currentX = event.touches[0].clientX;
        const diff = this._currentX - this._startX;

        // Use cached element reference
        const el = this._activeElement;
        const translate = Math.max(Math.min(diff, 100), -100);
        el.style.transform = `translateX(${translate}px)`;

        // Toggle swipe classes on parent
        const parent = el.parentElement;
        if (parent) {
            parent.classList.toggle('swiping-right', diff > 20);
            parent.classList.toggle('swiping-left', diff < -20);
        }
    }

    @action
    handleTouchEnd(animeId) {
        if (!this._activeSwipeId || this.editMode) return;

        const diff = this._currentX - this._startX;

        // Use cached element reference
        if (this._activeElement) {
            this._activeElement.style.transform = '';
            const parent = this._activeElement.parentElement;
            if (parent) {
                parent.classList.remove('swiping-left', 'swiping-right');
            }
        }

        // Trigger actions based on swipe distance
        if (diff > 80) {
            this.setStatusDirectly(animeId, 'completed');
        } else if (diff < -80) {
            this.removeFromWatchlist(animeId);
        }

        // Reset state
        this._activeSwipeId = null;
        this._activeElement = null;
        this._startX = 0;
        this._currentX = 0;
    }

    // Computed getters - Single pass optimization
    get filteredModel() {
        const term = (this.searchTerm || "").trim().toLowerCase();
        let items = this.model || [];

        // Filter by status if not "all"
        if (this.activeFilter !== "all") {
            items = items.filter(item => item.status === this.activeFilter);
        }

        // Filter by search term
        if (term) {
            items = items.filter(item =>
                (item.title || "").toLowerCase().includes(term)
            );
        }

        return items;
    }

    // Sorted and filtered model for table display
    get sortedFilteredModel() {
        const items = [...this.filteredModel];
        const col = this.sortColumn;
        const dir = this.sortDirection === "asc" ? 1 : -1;

        items.sort((a, b) => {
            let valA, valB;

            if (col === "title") {
                valA = (a.title || "").toLowerCase();
                valB = (b.title || "").toLowerCase();
                return valA.localeCompare(valB) * dir;
            } else if (col === "score") {
                valA = a.score || 0;
                valB = b.score || 0;
                return (valA - valB) * dir;
            } else if (col === "progress") {
                valA = a.episodes_watched || 0;
                valB = b.episodes_watched || 0;
                return (valA - valB) * dir;
            }

            return 0;
        });

        return items;
    }

    // Category title for banner
    get categoryTitle() {
        const titles = {
            all: "All Anime",
            watching: "Currently Watching",
            completed: "Completed",
            on_hold: "On Hold",
            dropped: "Dropped",
            plan_to_watch: "Plan to Watch"
        };
        return titles[this.activeFilter] || "All Anime";
    }

    // Single-pass grouping for all status categories
    get groupedByStatus() {
        const groups = {
            watching: [],
            plan_to_watch: [],
            completed: [],
            on_hold: [],
            dropped: []
        };

        for (const item of this.filteredModel) {
            if (groups[item.status]) {
                groups[item.status].push(item);
            }
        }

        return groups;
    }

    get watching() {
        return this.groupedByStatus.watching;
    }

    get planned() {
        return this.groupedByStatus.plan_to_watch;
    }

    get completed() {
        return this.groupedByStatus.completed;
    }

    get onHold() {
        return this.groupedByStatus.on_hold;
    }

    get dropped() {
        return this.groupedByStatus.dropped;
    }

    @action
    setActiveFilter(filter) {
        this.vibrate(5);
        this.activeFilter = filter;
    }

    @action
    sortBy(column) {
        this.vibrate(5);
        if (this.sortColumn === column) {
            // Toggle direction
            this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
        } else {
            this.sortColumn = column;
            this.sortDirection = "asc";
        }
    }

    @action
    async incrementProgress(event) {
        const animeId = event.currentTarget.dataset.animeId;
        this.vibrate(10);

        const item = this.model.find(i => i.anime_id === Number(animeId) || i.anime_id === animeId);
        if (!item) return;

        const newCount = (item.episodes_watched || 0) + 1;

        try {
            await ajax("/anime/watchlist", {
                method: "POST",
                data: {
                    anime_id: animeId,
                    episodes_watched: newCount,
                    status: item.status
                }
            });

            // Update local model
            item.episodes_watched = newCount;

            // Auto-complete if reached total
            if (item.total_episodes && newCount >= item.total_episodes) {
                item.status = "completed";
            }

            this.model = [...this.model];
        } catch (error) {
            console.error("Failed to update progress:", error);
        }
    }

    @action
    isItemSelected(animeId) {
        this.selectionTrigger; // Trigger reactivity
        return this.selectedIds.has(animeId);
    }

    @action
    toggleEditMode() {
        this.vibrate(5);
        this.editMode = !this.editMode;
        if (!this.editMode) {
            this.selectedIds.clear();
            this.selectionTrigger++;
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
        this.selectionTrigger++;
    }

    get isAllSelected() {
        this.selectionTrigger; // Trigger reactivity
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
        this.selectionTrigger++;
    }

    @action
    handleStatusToggle(event) {
        const animeId = event.currentTarget.dataset.animeId;
        this.vibrate(5);

        if (this.openDropdownId === animeId) {
            this.openDropdownId = null;
        } else {
            this.openDropdownId = animeId;
        }
    }

    @action
    async handleStatusChange(event) {
        const animeId = event.currentTarget.dataset.animeId;
        const newStatus = event.currentTarget.dataset.status;

        this.vibrate(10);
        this.openDropdownId = null;

        try {
            await ajax("/anime/watchlist", {
                method: "POST",
                data: {
                    anime_id: animeId,
                    status: newStatus
                }
            });

            // Update local model
            const item = this.model.find(i => i.anime_id === Number(animeId) || i.anime_id === animeId);
            if (item) {
                item.status = newStatus;
                // Trigger reactivity by creating a new array
                this.model = [...this.model];
            }
        } catch (error) {
            console.error("Failed to update status:", error);
            alert("Failed to update status. Please try again.");
        }
    }

    @action
    async handleDelete(event) {
        const animeId = event.currentTarget.dataset.animeId;
        this.vibrate(10);

        if (!confirm("Remove this anime from your watchlist?")) return;

        try {
            await ajax(`/anime/watchlist/${animeId}`, {
                method: "DELETE"
            });

            // Remove from local model
            this.model = this.model.filter(i => i.anime_id !== Number(animeId) && i.anime_id !== animeId);
        } catch (error) {
            console.error("Failed to remove from watchlist:", error);
            alert("Failed to remove. Please try again.");
        }
    }

    // Legacy methods (kept for backward compatibility with other templates)
    @action
    toggleStatusDropdown(animeId) {
        this.vibrate(5);

        if (this.openDropdownId === animeId) {
            this.openDropdownId = null;
        } else {
            this.openDropdownId = animeId;
        }
    }

    @action
    async setStatusDirectly(animeId, newStatus) {
        this.vibrate(10);
        this.openDropdownId = null;

        try {
            await ajax("/anime/watchlist", {
                method: "POST",
                data: {
                    anime_id: animeId,
                    status: newStatus
                }
            });

            // Update local model
            const item = this.model.find(i => i.anime_id === Number(animeId) || i.anime_id === animeId);
            if (item) {
                item.status = newStatus;
                // Trigger reactivity by creating a new array
                this.model = [...this.model];
            }
        } catch (error) {
            console.error("Failed to update status:", error);
            alert("Failed to update status. Please try again.");
        }
    }

    @action
    async bulkDelete() {
        if (this.selectedIds.size === 0) return;

        this.vibrate(10);
        if (!confirm(`Remove ${this.selectedIds.size} items from your watchlist?`)) return;

        this.isLoading = true;
        const idsToRemove = Array.from(this.selectedIds);

        try {
            // Process in parallel with error collection
            const results = await Promise.allSettled(
                idsToRemove.map(id => ajax(`/anime/watchlist/${id}`, { type: "DELETE" }))
            );

            const failedCount = results.filter(r => r.status === 'rejected').length;
            if (failedCount > 0) {
                console.warn(`${failedCount} items failed to delete`);
            }

            const newModel = (this.model || []).filter(item => !this.selectedIds.has(item.anime_id));
            this.model = newModel;
            this.selectedIds.clear();
            this.editMode = false;
            this.vibrate([10, 50, 10]);
        } catch (error) {
            console.error("Bulk delete error:", error);
        } finally {
            this.isLoading = false;
        }
    }

    @action
    async bulkChangeStatus(status) {
        if (this.selectedIds.size === 0) return;

        this.vibrate(10);
        this.isLoading = true;
        const idsToUpdate = Array.from(this.selectedIds);

        try {
            const results = await Promise.allSettled(idsToUpdate.map(id => {
                const item = this.model.find(i => i.anime_id === id);
                if (!item) return Promise.reject('Item not found');

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

            const failedCount = results.filter(r => r.status === 'rejected').length;
            if (failedCount > 0) {
                console.warn(`${failedCount} items failed to update`);
            }

            // Update model locally
            this.model = this.model.map(item => {
                if (this.selectedIds.has(item.anime_id)) {
                    return { ...item, status };
                }
                return item;
            });
            this.selectedIds.clear();
            this.editMode = false;
            this.vibrate([10, 50, 10]);
        } catch (error) {
            console.error("Bulk update error:", error);
        } finally {
            this.isLoading = false;
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
            this.model = this.model.map(i => i.anime_id === animeId ? { ...i, status } : i);
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
            this.model = (this.model || []).filter(item => item.anime_id !== animeId);
            this.vibrate([10, 50, 10]);
        } catch (error) {
            console.error("Error removing from watchlist:", error);
        }
    }
}
