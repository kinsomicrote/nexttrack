# NextTrack

A music recommendation application that suggests tracks based on harmonic compatibility, tempo matching, and audio feature similarity. Given a Spotify track ID, NextTrack queries MusicBrainz for culturally similar candidates, scores them using the Circle of Fifths and DJ-style BPM rules, and returns ranked recommendations.

---

## Requirements

- **Ruby** 3.4.7
- **Bundler** 2.x (`gem install bundler`)
- **Node.js** (for Tailwind CSS compilation)

---

## Setup

### 1. Clone and install dependencies

```bash
git clone git@github.com:kinsomicrote/nexttrack.git
cd nexttrack
bundle install
```

### 2. Add the master key

Spotify credentials are already embedded in the repo as an encrypted file (`config/credentials.yml.enc`). To decrypt them, place the provided `master.key` file into `config/`:

```
config/master.key
```

This file is submitted separately and is the only credential setup required. No Spotify account or API registration is needed.

> **Note:** MusicBrainz and ReccoBeats (the other two APIs) require no credentials at all.

---

## Running the Server

```bash
bin/dev
```

This starts the Rails server and the Tailwind CSS watcher together. The application is then available at:

```
http://localhost:3000
```

To start just the Rails server without asset compilation:

```bash
bin/rails server
```

---

## Using the Application

Open `http://localhost:3000` in a browser. The interface provides:

1. **Track search** — type an artist or track name to find a Spotify track
2. **Recommendation** — once a track is selected, click _Get Recommendations_ to receive ranked suggestions
3. **Audio features toggle** — disable audio feature scoring to use cultural similarity only
4. **Target sliders** — optionally bias results toward a desired energy or valence level

You can also interact with the API directly:

### Search for a track

```bash
GET /api/v1/tracks/search?q=sunset+lover
```

### Get recommendations

```bash
POST /api/v1/recommendations
Content-Type: application/json

{
  "track_id": "5W3cjX2J3tjhG8zb6u0qHn",
  "use_audio_features": true,
  "limit": 5,
  "targets": {
    "energy": 0.8,
    "valence": 0.6
  }
}
```

**Response fields:**

- `seed_track` — the input track with its audio features
- `recommendations` — array of ranked results, each with `rank`, `track`, `confidence` (0–100), `reasons`, and `scores`
- `recommendation` — top result in a flat format (backward-compatibility field)
- `metadata` — processing notes and candidate count

---

## Running the Tests

```bash
bin/rails test
```

This runs all **196 tests** (181 unit tests + 15 integration/controller tests). No API calls are mocked — integration tests make live requests to the Spotify and ReccoBeats APIs, so an internet connection and valid Spotify credentials are required.

To run a specific test file:

```bash
bin/rails test test/models/similarity_scorer_test.rb
```

To run a single test by name:

```bash
bin/rails test test/models/tempo_matcher_test.rb -n "test_describe_relationship_for_double_time"
```

## Project Structure

```
app/
  models/
    recommendation_engine.rb   # Orchestrates the full recommendation pipeline
    similarity_scorer.rb       # Multi-dimensional scoring (cosine similarity)
    audio_features.rb          # Value object for track audio characteristics
    key_compatibility.rb       # Circle of Fifths harmonic compatibility rules
    tempo_matcher.rb           # DJ-style BPM matching with tiered scoring
    recommendation_response.rb # Formats results into API response structure
    spotify.rb                 # Spotify Web API client (track lookup, search)
    music_brainz.rb            # MusicBrainz API client (cultural similarity)
    recco_beats.rb             # ReccoBeats API client (audio feature analysis)
  controllers/
    api/v1/recommendations_controller.rb
    api/v1/tracks_controller.rb
  javascript/
    controllers/recommendation_controller.js  # Stimulus controller for the UI
test/
  models/                      # Unit tests for all domain models
  controllers/                 # Controller-level tests
  integration/                 # End-to-end flow tests
```

---

## External APIs

| Service         | Purpose                             | Auth                           |
| --------------- | ----------------------------------- | ------------------------------ |
| Spotify Web API | Track lookup, search                | Client credentials (see setup) |
| MusicBrainz     | Genre tags, cultural similarity     | None required                  |
| ReccoBeats      | Audio features (tempo, key, energy) | None required                  |
