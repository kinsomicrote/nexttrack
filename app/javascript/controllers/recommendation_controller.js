import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "trackInput",
    "trackId",
    "dropdown",
    "dropdownLoading",
    "dropdownEmpty",
    "dropdownList",
    "selectedTrack",
    "selectedImage",
    "selectedName",
    "selectedArtist",
    "selectedAlbum",
    "useAudioFeatures",
    "energy",
    "valence",
    "limit",
    "submitButton",
    "buttonText",
    "spinner",
    "loadingMessage",
    "results",
    "seedTrack",
    "seedFeatures",
    "trackName",
    "artistName",
    "score",
    "audioFeaturesStatus",
    "reason",
    "playerContainer",
    "spotifyLink",
    "otherRecommendations",
    "error",
    "errorMessage",
  ];

  static TRACK_ID_PATTERN = /^[a-zA-Z0-9]{22}$/;

  searchTimeout = null;

  highlightedIndex = -1;

  searchResults = [];

  connect() {
    this.handleDocumentClick = this.handleDocumentClick.bind(this);
    document.addEventListener("click", this.handleDocumentClick);

    // Initialize toggle visual state
    this.updateToggleVisual();
    this.useAudioFeaturesTarget.addEventListener("change", () => this.updateToggleVisual());
  }

  updateToggleVisual() {
    const toggle = this.useAudioFeaturesTarget.nextElementSibling;
    if (toggle && toggle.classList.contains("neon-toggle")) {
      if (this.useAudioFeaturesTarget.checked) {
        toggle.classList.add("active");
      } else {
        toggle.classList.remove("active");
      }
    }
  }

  disconnect() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
    }
    document.removeEventListener("click", this.handleDocumentClick);
  }

  handleDocumentClick(event) {
    const isClickInsideDropdown = this.dropdownTarget.contains(event.target);
    const isClickInsideInput = this.trackInputTarget.contains(event.target);

    if (
      !isClickInsideDropdown &&
      !isClickInsideInput &&
      this.isDropdownOpen()
    ) {
      this.closeDropdown();
    }
  }

  onDropdownClick(event) {
    const listItem = event.target.closest("li[data-index]");
    if (listItem) {
      event.preventDefault();
      event.stopPropagation();
      const index = parseInt(listItem.dataset.index, 10);
      this.selectTrackByIndex(index);
    }
  }

  onInput(event) {
    const query = event.target.value.trim();

    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
    }

    if (this.constructor.TRACK_ID_PATTERN.test(query)) {
      this.closeDropdown();
      this.trackIdTarget.value = query;
      this.hideSelectedTrack();
      return;
    }

    if (query.length < 2) {
      this.closeDropdown();
      return;
    }

    this.searchTimeout = setTimeout(() => {
      this.performSearch(query);
    }, 300);
  }

  onKeydown(event) {
    if (!this.isDropdownOpen()) return;

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.highlightNext();
        break;
      case "ArrowUp":
        event.preventDefault();
        this.highlightPrevious();
        break;
      case "Enter":
        event.preventDefault();
        this.selectHighlighted();
        break;
      case "Escape":
        this.closeDropdown();
        break;
    }
  }

  async performSearch(query) {
    this.showDropdownLoading();

    try {
      const response = await fetch(
        `/api/v1/tracks/search?q=${encodeURIComponent(query)}`,
        {
          headers: {
            Accept: "application/json",
          },
        },
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.details || data.error || "Search failed");
      }

      this.searchResults = data.results || [];
      this.renderSearchResults();
    } catch (error) {
      console.error("Search error:", error);
      this.showDropdownEmpty();
    }
  }

  renderSearchResults() {
    if (this.searchResults.length === 0) {
      this.showDropdownEmpty();
      return;
    }

    this.highlightedIndex = -1;

    const html = this.searchResults
      .map(
        (track, index) => `
      <li
        data-index="${index}"
        class="dropdown-item p-3 flex items-center gap-3"
      >
        <img
          src="${track.image_url || ""}"
          alt=""
          class="w-12 h-12 rounded-lg object-cover bg-white/10 shrink-0"
          onerror="this.style.display='none'"
        >
        <div class="flex-1 min-w-0">
          <p class="text-white font-semibold truncate">${this.escapeHtml(track.name)}</p>
          <p class="text-white/60 text-sm truncate">${this.escapeHtml(track.artist)}</p>
          <p class="text-white/40 text-xs truncate">${this.escapeHtml(track.album)}${track.year ? ` • ${track.year}` : ""}</p>
        </div>
      </li>
    `,
      )
      .join("");

    this.dropdownListTarget.innerHTML = html;
    this.showDropdownList();
  }

  showDropdownLoading() {
    this.openDropdown();
    this.dropdownLoadingTarget.style.display = "block";
    this.dropdownEmptyTarget.style.display = "none";
    this.dropdownListTarget.style.display = "none";
  }

  showDropdownEmpty() {
    this.openDropdown();
    this.dropdownLoadingTarget.style.display = "none";
    this.dropdownEmptyTarget.style.display = "block";
    this.dropdownListTarget.style.display = "none";
  }

  showDropdownList() {
    this.openDropdown();
    this.dropdownLoadingTarget.style.display = "none";
    this.dropdownEmptyTarget.style.display = "none";
    this.dropdownListTarget.style.display = "block";
  }

  openDropdown() {
    this.dropdownTarget.classList.remove("hidden");
  }

  closeDropdown() {
    this.dropdownTarget.classList.add("hidden");
    this.highlightedIndex = -1;
  }

  isDropdownOpen() {
    return !this.dropdownTarget.classList.contains("hidden");
  }

  highlightNext() {
    const maxIndex = this.searchResults.length - 1;
    const newIndex =
      this.highlightedIndex < maxIndex ? this.highlightedIndex + 1 : 0;
    this.setHighlight(newIndex);
  }

  highlightPrevious() {
    const maxIndex = this.searchResults.length - 1;
    const newIndex =
      this.highlightedIndex > 0 ? this.highlightedIndex - 1 : maxIndex;
    this.setHighlight(newIndex);
  }

  setHighlight(index) {
    const items = this.dropdownListTarget.querySelectorAll("li");
    items.forEach((item, i) => {
      if (i === index) {
        item.classList.add("active");
        item.scrollIntoView({ block: "nearest" });
      } else {
        item.classList.remove("active");
      }
    });
    this.highlightedIndex = index;
  }

  selectHighlighted() {
    if (
      this.highlightedIndex >= 0 &&
      this.highlightedIndex < this.searchResults.length
    ) {
      this.selectTrackByIndex(this.highlightedIndex);
    }
  }

  selectTrackByIndex(index) {
    const track = this.searchResults[index];
    if (!track) return;

    this.trackIdTarget.value = track.id;

    this.trackInputTarget.value = `${track.name} - ${track.artist}`;

    this.selectedImageTarget.src = track.image_url || "";
    this.selectedNameTarget.textContent = track.name;
    this.selectedArtistTarget.textContent = track.artist;
    this.selectedAlbumTarget.textContent = `${track.album}${track.year ? ` • ${track.year}` : ""}`;
    this.selectedTrackTarget.classList.remove("hidden");

    this.trackInputTarget.classList.add("hidden");

    this.closeDropdown();
  }

  clearSelection() {
    this.trackIdTarget.value = "";
    this.trackInputTarget.value = "";
    this.trackInputTarget.classList.remove("hidden");
    this.hideSelectedTrack();
    this.trackInputTarget.focus();
  }

  hideSelectedTrack() {
    this.selectedTrackTarget.classList.add("hidden");
  }

  async search(event) {
    event.preventDefault();

    let trackId = this.trackIdTarget.value.trim();

    if (!trackId) {
      const inputValue = this.trackInputTarget.value.trim();
      if (this.constructor.TRACK_ID_PATTERN.test(inputValue)) {
        trackId = inputValue;
      }
    }

    if (!trackId) {
      this.showError(
        "Please select a track from the search results or enter a valid Spotify track ID",
      );
      return;
    }

    this.setLoading(true);
    this.hideResults();
    this.hideError();

    // Get limit from input (default to 5, clamp between 1-10)
    const limitValue = this.hasLimitTarget ? parseInt(this.limitTarget.value, 10) : 5;
    const limit = Math.min(Math.max(limitValue || 5, 1), 10);

    const body = { track_id: trackId, limit: limit };

    // Audio features toggle
    const useAudioFeatures = this.useAudioFeaturesTarget.checked;
    body.use_audio_features = useAudioFeatures;

    const energy = this.energyTarget.value;
    const valence = this.valenceTarget.value;

    if (energy || valence) {
      body.targets = {};
      if (energy) body.targets.energy = parseFloat(energy);
      if (valence) body.targets.valence = parseFloat(valence);
    }

    try {
      const response = await fetch("/api/v1/recommendations", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(body),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.details || data.error || "Request failed");
      }

      this.displayResults(data);
    } catch (error) {
      this.showError(error.message);
    } finally {
      this.setLoading(false);
    }
  }

  setLoading(isLoading) {
    this.submitButtonTarget.disabled = isLoading;
    this.spinnerTarget.classList.toggle("hidden", !isLoading);
    this.loadingMessageTarget.classList.toggle("hidden", !isLoading);
    if (isLoading) {
      this.buttonTextTarget.innerHTML = "Analyzing...";
    } else {
      this.buttonTextTarget.innerHTML = `
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path d="M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.37 4.37 0 0015 12c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"></path>
        </svg>
        Find Next Track
      `;
    }
  }

  displayResults(data) {
    const audioFeaturesEnabled = data.audio_features_enabled;
    const seedTrack = data.seed_track;
    const recommendations = data.recommendations || [];
    const topRec = recommendations[0];

    // Display seed track info
    this.seedTrackTarget.textContent = `${seedTrack.name} by ${seedTrack.artist}`;

    // Display seed features if available
    if (seedTrack.features && this.hasSeedFeaturesTarget) {
      const f = seedTrack.features;
      this.seedFeaturesTarget.textContent = `${f.key} • ${f.tempo} BPM • Energy: ${f.energy} • Valence: ${f.valence}`;
    }

    // Display top recommendation
    if (topRec) {
      this.trackNameTarget.textContent = topRec.track.name;
      this.artistNameTarget.textContent = topRec.track.artist;
      this.scoreTarget.textContent = topRec.confidence;
      this.reasonTarget.textContent = topRec.reasons.join(" • ");
      this.spotifyLinkTarget.href = topRec.track.spotify_url;

      // Embed Spotify player — spotify_id is a controlled alphanumeric string from the API
      this.playerContainerTarget.innerHTML = `
        <iframe
          style="border-radius:12px"
          src="https://open.spotify.com/embed/track/${topRec.track.spotify_id}?utm_source=generator&theme=0"
          width="100%"
          height="152"
          frameBorder="0"
          allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
          loading="lazy">
        </iframe>
      `;
    }

    // Show audio features status
    if (audioFeaturesEnabled) {
      this.audioFeaturesStatusTarget.textContent = "🎹 Audio Features ON";
      this.audioFeaturesStatusTarget.classList.remove("bg-gray-500/20", "text-gray-400");
      this.audioFeaturesStatusTarget.classList.add("bg-blue-500/20", "text-blue-400");
    } else {
      this.audioFeaturesStatusTarget.textContent = "📝 Metadata Only";
      this.audioFeaturesStatusTarget.classList.remove("bg-blue-500/20", "text-blue-400");
      this.audioFeaturesStatusTarget.classList.add("bg-gray-500/20", "text-gray-400");
    }

    // Display other recommendations (ranks 2-5)
    if (recommendations.length > 1 && this.hasOtherRecommendationsTarget) {
      const otherRecs = recommendations.slice(1);
      const html = otherRecs.map((rec) => `
        <div class="track-card p-3 flex items-center gap-3">
          <div class="flex items-center justify-center w-8 h-8 rounded-full bg-white/10 text-white/60 text-sm font-bold">
            ${rec.rank}
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-white font-medium truncate">${this.escapeHtml(rec.track.name)}</p>
            <p class="text-white/50 text-sm truncate">${this.escapeHtml(rec.track.artist)}</p>
          </div>
          <div class="text-right">
            <span class="text-neon-cyan font-bold">${rec.confidence}%</span>
            <p class="text-white/40 text-xs">${rec.reasons.slice(0, 2).join(", ")}</p>
          </div>
          <a
            href="${rec.track.spotify_url}"
            target="_blank"
            rel="noopener noreferrer"
            class="p-2 text-green-400 hover:text-green-300 transition-colors"
            title="Open in Spotify"
          >
            <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z"/>
            </svg>
          </a>
        </div>
      `).join("");

      this.otherRecommendationsTarget.innerHTML = html;
    } else if (this.hasOtherRecommendationsTarget) {
      this.otherRecommendationsTarget.innerHTML = '<p class="text-white/40 text-sm">No additional recommendations available</p>';
    }

    this.resultsTarget.classList.remove("hidden");
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden");
  }

  showError(message) {
    this.errorMessageTarget.textContent = message;
    this.errorTarget.classList.remove("hidden");
  }

  hideError() {
    this.errorTarget.classList.add("hidden");
  }

  reset() {
    this.hideResults();
    this.hideError();
    this.clearSelection();
    this.useAudioFeaturesTarget.checked = true;
    this.updateToggleVisual();
    this.energyTarget.value = "";
    this.valenceTarget.value = "";
    if (this.hasLimitTarget) {
      this.limitTarget.value = "5";
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
