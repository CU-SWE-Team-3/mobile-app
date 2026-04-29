# Module 4 — Upload Feature: Deep Technical Explanation

> **Purpose:** This file was generated from a live inspection of the actual codebase for use in a
> technical discussion. Every reference is tied to a real file, real class, or real function.
> Delete when no longer needed.

---

## Table of Contents

- [A. High-Level Overview](#a-high-level-overview)
- [B. Entry Points into Upload](#b-entry-points-into-upload)
- [C. Upload Flow End-to-End](#c-upload-flow-end-to-end)
- [D. File-by-File Explanation](#d-file-by-file-explanation)
- [E. Navigation and Routing Map](#e-navigation-and-routing-map)
- [F. State Management Explanation](#f-state-management-explanation)
- [G. Waveform Explanation](#g-waveform-explanation)
- [H. Backend / API / Network Integration](#h-backend--api--network-integration)
- [I. Data Models](#i-data-models)
- [J. Bug Troubleshooting Guide](#j-bug-troubleshooting-guide)
- [K. Architecture Map](#k-architecture-map)
- [L. Important Notes / Hidden Gotchas](#l-important-notes--hidden-gotchas)
- [M. Final Quick Revision Sheet](#m-final-quick-revision-sheet)

---

## A. High-Level Overview

### What Module 4 Is

Module 4 is the **track upload feature**. It allows users with an "Artist" account role to:
1. Pick an audio file from device storage.
2. Fill in track metadata (title, artist, genre, tags, description, cover art, privacy, schedule).
3. Submit the track for upload to a backend API that stores audio in **Azure Blob Storage**.
4. Monitor upload progress while the server processes the file.
5. View the uploaded track in the "Your Uploads" library section.

### User Journeys

| Journey | Start point | End point |
|---|---|---|
| Primary | Library tab → "Your uploads" → FAB `+` | `/library/uploads` after success |
| Re-edit | Library tab → "Your uploads" → long-press track → Edit | `/library/uploads` |
| Deep link to edit | Global route `/upload` | `/upload/progress` |

### Where Upload Starts and Ends

- **Starts:** `LibraryUploadsPage` (`lib/features/library/presentation/pages/library_uploads_page.dart`) — the FAB triggers file picking.
- **Middle:** `UploadEditPage` (`lib/features/library/presentation/pages/upload_edit_page.dart`) — metadata form.
- **Ends:** `UploadProgressPage` (`lib/features/library/presentation/pages/upload_progress_page.dart`) — real HTTP upload runs here; on success auto-navigates to `/library/uploads`.

---

## B. Entry Points into Upload

### Entry Point 1 — Library Uploads FAB (Primary)

**File:** `lib/features/library/presentation/pages/library_uploads_page.dart`

- The Floating Action Button (bottom-right) has `key: ValueKey('uploads_add_fab')`.
- `onPressed: () => _pickAndUpload(context)` at line 559.
- `_pickAndUpload()` does:
  1. Reads `role` from `SharedPreferences` — if not `'artist'`, shows `_showUpgradeRoleDialog()` and returns early.
  2. Opens `FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false)`.
  3. Calls `ref.read(uploadProvider.notifier).initializeUpload(audioFilePath: path)`.
  4. Navigates: `context.push('/upload')` → opens `UploadEditPage`.

**Navigation method:** `context.push('/upload')` — go_router push, puts `UploadEditPage` on the stack.

### Entry Point 2 — Library Page Menu Item

**File:** `lib/features/library/presentation/pages/library_page.dart`

- `_LibraryMenuItem(title: 'Your uploads', onTap: () => context.push('/library/uploads'))` at line 117.
- This opens `LibraryUploadsPage` first. The actual upload starts from the FAB there.

### Entry Point 3 — Edit Existing Track

**File:** `lib/features/library/presentation/pages/library_uploads_page.dart`

- Track options sheet → Edit tile: `context.push('/library/uploads/edit')` at line 193.
- This opens `UploadEditPage` (same page as above, different route path).

### Entry Point 4 — Global `/upload` Route (No Shell)

**File:** `lib/core/router/app_router.dart` lines 274–281

- `GoRoute(path: '/upload', builder: (_, __) => const UploadEditPage())`.
- Any widget in the app can call `context.push('/upload')` or `context.go('/upload')`.
- This route exists OUTSIDE the `StatefulShellRoute`, meaning the bottom nav bar is **hidden** when on this page.

### Where to Look First

- FAB button: `library_uploads_page.dart` → `_pickAndUpload()` method
- "Your uploads" menu item: `library_page.dart` line 117
- Route registration: `app_router.dart` lines 274–281

---

## C. Upload Flow End-to-End

### Step 1 — Role Check (before file picker opens)

**File:** `lib/features/library/presentation/pages/library_uploads_page.dart` — `_pickAndUpload()`

```
SharedPreferences → read 'role'
if role != 'artist' → show AlertDialog "Artist Role Required" → stop
else → proceed to step 2
```

### Step 2 — Audio File Selection

**File:** `lib/features/library/presentation/pages/library_uploads_page.dart` — `_pickAndUpload()`

- `FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false)` is called.
- On success: `result.files.first.path` holds the device file path.
- Provider call: `ref.read(uploadProvider.notifier).initializeUpload(audioFilePath: path)`.

**What `initializeUpload()` does** (in `lib/features/library/presentation/providers/upload_provider.dart`):
- Creates a new `UploadTrack` with `audioFilePath = path`.
- Pre-fills `title` by stripping file extension from the filename.
- Resets `artist` to empty string.
- Sets `state = state.copyWith(track: newTrack)`.

### Step 3 — Navigate to Metadata Form

- `context.push('/upload')` → router loads `UploadEditPage`.

### Step 4 — Metadata Entry (`UploadEditPage`)

**File:** `lib/features/library/presentation/pages/upload_edit_page.dart`

The page opens with controllers pre-populated from `uploadProvider` state:
```dart
_titleController = TextEditingController(text: uploadState.track.title);
_artistController = TextEditingController(text: uploadState.track.artist);
```

User can fill in:
- **Title** (required `*`) — `TextEditingController _titleController`
- **Artist** (required `*`) — `TextEditingController _artistController`
- **Cover image** — `_pickCoverImage()` uses `ImagePicker` (gallery). Stored in `uploadProvider` via `updateTrackField(coverImagePath: ...)`.
- **Genre** — bottom sheet (`_showGenrePicker()`), stored via `updateTrackField(genre: ...)`. 25 genres hardcoded in `_genreList`.
- **Tags** — text field + add button, stored via `updateTrackField(tags: _selectedTags)`.
- **Description** — max 4000 chars, stored via `updateTrackField(description: ...)`.
- **Privacy** — Public / Unlisted toggle, stored via `updateTrackField(isPublic: ...)`.
- **Schedule** — toggle + date/time picker (UI only, date/time stored locally in page state, **NOT sent to API yet**).

A **checklist progress indicator** (0/4) tracks: title filled, genre selected, description filled, cover set.

The "Replace file" button calls `context.pop()` — goes back to file picker in `LibraryUploadsPage`.

### Step 5 — Trigger Upload

**File:** `lib/features/library/presentation/pages/upload_edit_page.dart` — `_uploadTrack()` at line 197.

```dart
void _uploadTrack() {
  ref.read(uploadProvider.notifier).updateTrackField(
    title: _titleController.text.trim(),
    artist: _artistController.text.trim(),
    description: _descriptionController.text.trim(),
    genre: _selectedGenre,
    tags: _selectedTags,
    isPublic: ref.read(uploadProvider).track.isPublic,
  );
  context.push('/upload/progress');
}
```

**Note:** No validation here. Empty title/artist is allowed. The upload can start with empty fields.

### Step 6 — Upload Progress Page Auto-Starts Upload

**File:** `lib/features/library/presentation/pages/upload_progress_page.dart`

In `initState()`:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!_uploadStarted) {
    _uploadStarted = true;
    ref.read(uploadProvider.notifier).clearUploadStatus();
    ref.read(uploadProvider.notifier).uploadTrack();
  }
});
```

`uploadTrack()` is the real API call. It runs inside `UploadNotifier`.

### Step 7 — Real API Upload (6 sub-steps)

**File:** `lib/features/library/presentation/providers/upload_provider.dart` — `uploadTrack()`

#### 7a — Role re-check
```dart
final role = prefs.getString('role') ?? '';
if (role.toLowerCase() != 'artist') {
  state = state.copyWith(needsRoleUpgrade: true, error: 'Artist role required...');
  return;
}
```

#### 7b — Probe audio duration
- Reads audio file as bytes.
- Tries `just_audio` `AudioPlayer().setFilePath()` to get real duration in seconds.
- Fallback: estimates from file size `(bytes / 16000).clamp(1, 7200)`.
- Ensures `durationSeconds > 0`.

#### 7c — POST `/tracks/upload` (progress: 10%)
```dart
await dioClient.dio.post('/tracks/upload', data: {
  'title': ...,
  'format': mimeType,   // 'audio/mpeg', 'audio/wav', etc.
  'size': audioBytes.length,
  'duration': durationSeconds,
});
// Response: { data: { trackId: "...", uploadUrl: "..." } }
```

#### 7d — PUT to Azure Blob Storage (progress: 10% → 75%)
- Uses a **bare `Dio()` instance** (NOT `dioClient.dio`).
- **Critical:** Azure SAS URLs reject `Authorization` and `Cookie` headers — the shared client has both, so it MUST NOT be used here.
- Headers: `Content-Type`, `Content-Length`, `x-ms-blob-type: BlockBlob`.
- Streams bytes one at a time, tracks `onSendProgress`.

#### 7e — PATCH `/tracks/{trackId}/confirm` (progress: 80%)
- No body. Signals backend that blob is ready.
- Response includes `permalink` (URL-safe slug for polling).

#### 7f — PATCH `/tracks/{trackId}/metadata` (progress: 85%)
- Only sends non-empty fields: title, description, genre, tags, releaseDate.

#### 7g — PATCH `/tracks/{trackId}/artwork` (progress: 90%)
- Only runs if `coverImagePath != null`.
- Sends multipart `FormData` with field `'artwork'`.

#### 7h — Poll GET `/tracks/{permalink}` until `processingState == 'Finished'`
- `_pollProcessingStatus(permalink)`.
- Max 60 attempts, 3 seconds apart = up to 3 minutes.
- Updates `state.processingState` each poll.

#### 7i — Final success state
```dart
state = state.copyWith(
  isUploading: false, uploadProgress: 1.0,
  successMessage: 'Upload complete! ✓', processingState: 'Finished'
);
```

### Step 8 — Auto Navigation After Success

**File:** `lib/features/library/presentation/pages/upload_progress_page.dart`

```dart
if (isComplete && uploadState.successMessage != null) {
  Future.delayed(Duration(milliseconds: 1500), () {
    context.go('/library/uploads');
  });
}
```

Also: "View in My Uploads" button → `context.go('/library/uploads')`.
"Upload Another Track" button → `context.go('/upload')` (back to edit form, state preserved).

---

## D. File-by-File Explanation

### `lib/features/library/presentation/pages/library_uploads_page.dart`

- **Role:** The "Your Uploads" list screen. Also the primary entry point for initiating new uploads.
- **Key widgets:** FAB (`uploads_add_fab`), search field (`uploads_search_field`), track list tiles (`uploads_track_tile`).
- **Providers watched:** `playerProvider`, `myTracksProvider`.
- **Providers written:** `uploadProvider.notifier.initializeUpload()`, `uploadProvider.notifier.upgradeToArtist()`, `playerProvider.notifier.playTrackFromFile()`.
- **Data source:** `myTracksProvider` — FutureProvider that calls `GET /tracks/my-tracks`.
- **Inputs:** None (reads from providers + SharedPreferences).
- **Outputs:** Navigation to `/upload` (edit form), `/library/uploads/edit`.
- **Depends on:** `upload_provider.dart`, `my_tracks_provider.dart`, `player_provider.dart`.

### `lib/features/library/presentation/pages/upload_edit_page.dart`

- **Role:** Metadata form for the track. The user fills title, artist, genre, tags, description, cover image, privacy.
- **Key widgets:** Title field (`upload_track_title_field`), artist field (no key), genre picker (`upload_genre_picker`), cover image tap area (`upload_cover_image_button`), upload button (`upload_track_submit_button`).
- **State management:** Local `TextEditingController`s + writes to `uploadProvider` on changes.
- **Providers written:** `uploadProvider.notifier.updateTrackField()` on every change.
- **Navigation out:** `context.push('/upload/progress')` when "Upload Track" tapped.
- **Navigation back:** "Replace file" button calls `context.pop()`.
- **Cover image picker:** Uses `image_picker` package (gallery source only).
- **Schedule section:** UI toggle + date/time pickers are local state only — **NOT wired to the API**. The schedule date is NOT sent to the backend.
- **Checklist:** Tracks 4 items (title, genre, description, cover) for a completeness indicator.

### `lib/features/library/presentation/pages/upload_progress_page.dart`

- **Role:** Shows upload progress and handles all error/success states.
- **Auto-starts upload** via `initState()` → `postFrameCallback` → `uploadTrack()`.
- **Blocks back navigation** while uploading (`PopScope(canPop: !uploadState.isUploading && !isProcessing)`).
- **States shown:**
  - `isUploading == true` → circular + linear progress, percent label.
  - `processingState != null && != 'Finished'` → "Processing on server..." label.
  - `needsRoleUpgrade == true` → orange "Artist Role Required" box with upgrade button.
  - `error != null` → red error box + "Try Again" button.
  - `isComplete == true` → success box + "View in My Uploads" + "Upload Another Track".
- **Key ValueKeys:** `upload_progress_back_button`, `upload_progress_upgrade_button`, `upload_progress_view_uploads_button`, `upload_progress_upload_another_button`, `upload_progress_retry_button`.
- **Auto-navigates** to `/library/uploads` 1500ms after success.
- **Retry:** Calls `clearUploadStatus()` then `uploadTrack()` again.

### `lib/features/library/presentation/providers/upload_provider.dart`

- **Role:** THE authoritative upload state container. Everything related to upload reads from and writes to this.
- **Classes:** `UploadState`, `UploadNotifier extends StateNotifier<UploadState>`.
- **Providers:** `uploadProvider` (main), `uploadedTracksProvider` (in-memory list, currently not used by main flow).
- **Key methods:** See Section F.
- **Dependencies:** `DioClient` (via `dioClientProvider`), `just_audio`, `shared_preferences`, `path`, `dio`.

### `lib/features/library/presentation/providers/my_tracks_provider.dart`

- **Role:** Fetches the list of user's uploaded tracks from the server.
- **Type:** `FutureProvider.autoDispose<List<UploadTrack>>`.
- **API call:** `GET /tracks/my-tracks`.
- **Data mapping:** Maps server JSON to `UploadTrack` objects (title, artist, genre, description, isPublic, duration — no file paths since tracks are server-side).
- **Used by:** `LibraryUploadsPage`.

### `lib/features/library/domain/entities/upload_track.dart`

- **Role:** The data model for a track being uploaded or already uploaded. Equatable with 12 props.
- **Fields:** `audioFilePath`, `coverImagePath`, `title`, `artist`, `album`, `genre`, `tags`, `releaseDate`, `isPublic`, `description`, `duration`, `processingState`.
- See Section I for full field descriptions.

### `lib/core/router/app_router.dart`

- **Role:** Defines all navigation routes using go_router.
- **Upload-relevant routes:** Lines 274–281 (global `/upload`, `/upload/progress`) and lines 222–232 (shell `/library/uploads`, `/library/uploads/edit`, `/library/uploads/progress`).
- See Section E for full routing map.

### `lib/core/widgets/app_shell.dart`

- **Role:** Persistent scaffold wrapping the 5-tab shell. Shows bottom nav bar and mini player bar.
- **Bottom nav tabs:** Home(0), Feed(1), Search(2), Library(3), Upgrade(4).
- **Mini player:** Hidden on Feed tab (index 1). Visible on all other tabs when a track is playing.
- **Upload connection:** No direct upload logic here. Library tab (index 3) leads to `LibraryPage` → `LibraryUploadsPage`.

### `lib/core/network/dio_client.dart`

- **Role:** Singleton HTTP client. Base URL: `https://biobeats.duckdns.org/api`.
- **Auth:** Bearer token in `dio.options.headers['Authorization']`. Persisted in SharedPreferences as `'accessToken'`.
- **Cookie support:** `PersistCookieJar` with file storage.
- **Auto-refresh:** `InterceptorsWrapper` retries on 401 with refresh token from `'refreshToken'` key in SharedPreferences.
- **Critical upload note:** The Azure Blob Storage PUT step uses a **separate bare `Dio()` instance** — NOT this client — to avoid sending auth headers to Azure.

### `lib/features/library/presentation/pages/library_page.dart`

- **Role:** The Library tab's home page. A menu list of sections.
- **Upload connection:** `_LibraryMenuItem(title: 'Your uploads', onTap: () => context.push('/library/uploads'))` at line 117.
- **Navigation method:** `context.push('/library/uploads')` → go_router push within the Library shell branch.

### `lib/features/upload/presentation/pages/upload_page.dart` ⚠️ ORPHANED

- **Status:** NOT registered in the router. Not imported by any active file. **This file does nothing in the running app.**
- **What it contains:** A full metadata form (different implementation than `UploadEditPage`). Has waveform placeholder visualization. Imports from `lib/features/library/presentation/providers/upload_provider.dart`.
- **Do not confuse** with `lib/features/library/presentation/pages/upload_page.dart`.

### `lib/features/upload/presentation/pages/upload_progress_page.dart` ⚠️ ORPHANED

- **Status:** NOT registered in the router. Not imported by any active file. **This file does nothing in the running app.**
- **What it contains:** A simpler progress page without the processing/role-upgrade states.

### `lib/features/upload/presentation/providers/upload_provider.dart` ⚠️ STUB / LEGACY

- **Status:** Not imported by any active page. Contains a duplicate `UploadState`, `UploadNotifier`, `uploadProvider`.
- **What it contains:** `simulateUpload()` (fake progress loop), `updateTrackField()`, `setWaveformLoaded()`.
- **Import:** `import '../../../library/domain/entities/upload_track.dart'` (imports `UploadTrack` from library).
- **Risk:** If accidentally imported alongside the library provider, you get naming conflicts (`UploadState` defined twice in the same file would error).

### `lib/features/library/presentation/pages/upload_page.dart` ⚠️ ALSO ORPHANED

- **Status:** Exists at this path (confirmed), but NOT registered in the router.
- **What it contains:** A file-picker landing page — shows an upload icon, "Choose Audio File" button, opens `FilePicker`, calls `initializeUpload()`, then navigates to `/upload/edit`.
- **Note:** The route `/upload/edit` does NOT exist in the router (the actual edit page is at `/upload`, not `/upload/edit`). If this page ever got routed to and its navigation ran, it would 404.

### `test/features/upload/upload_track_test.dart`

- **Role:** Tests the `UploadTrack` entity.
- **Assertions include:** 12 Equatable props, field defaults (isPublic=true, tags=[]), copyWith, processingState field.

### `test/features/upload/upload_provider_test.dart` (if exists)

- **Role:** Tests `UploadState` and `UploadNotifier`.

---

## E. Navigation and Routing Map

### Router File

`lib/core/router/app_router.dart` — `final appRouter = GoRouter(...)`.

Attached to the app in `lib/main.dart`:
```dart
MaterialApp.router(routerConfig: appRouter)
```

### Upload-Specific Routes

```
/upload
  └─ UploadEditPage  (lib/features/library/presentation/pages/upload_edit_page.dart)
     [GLOBAL — outside shell, no bottom nav bar]
  └─ /upload/progress
       └─ UploadProgressPage  (lib/features/library/presentation/pages/upload_progress_page.dart)
       [GLOBAL — outside shell]

/library  (Shell Branch 3 — Library tab)
  └─ LibraryPage
  └─ /library/uploads
       └─ LibraryUploadsPage
          └─ /library/uploads/edit
               └─ UploadEditPage  (same class as /upload)
          └─ /library/uploads/progress
               └─ UploadProgressPage  (same class as /upload/progress)
```

### Full Navigation Sequence (Primary Flow)

```
[Library Tab] → /library
   ↓  tap "Your uploads"
/library/uploads (LibraryUploadsPage)
   ↓  tap FAB "+"  →  role check  →  FilePicker  →  initializeUpload()
context.push('/upload')
   ↓
/upload (UploadEditPage)  — bottom nav hidden
   ↓  fill metadata  →  tap "Upload Track"
context.push('/upload/progress')
   ↓
/upload/progress (UploadProgressPage)  — uploadTrack() auto-starts
   ↓  upload completes
context.go('/library/uploads')  [auto after 1.5s] or button tap
   ↓
/library/uploads (LibraryUploadsPage)  — refreshed track list
```

### Navigation Methods Used

| Action | Method | File |
|---|---|---|
| Open Library | `context.push('/library/uploads')` | `library_page.dart` |
| Open edit form after file pick | `context.push('/upload')` | `library_uploads_page.dart` |
| Open progress page | `context.push('/upload/progress')` | `upload_edit_page.dart` |
| Return to uploads after success | `context.go('/library/uploads')` | `upload_progress_page.dart` |
| Upload another (reset & re-edit) | `context.go('/upload')` | `upload_progress_page.dart` |
| Back button on edit page | `context.pop()` | `upload_edit_page.dart` |

**Difference between `push` and `go`:**
- `context.push()` stacks the new route on top (back button works).
- `context.go()` replaces the stack (used after success to prevent back-navigation to the upload form).

---

## F. State Management Explanation

### Provider

```dart
final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return UploadNotifier(dioClient);
});
```

**File:** `lib/features/library/presentation/providers/upload_provider.dart`

This is a global (app-wide) provider — it persists across navigation. State is NOT reset between screens unless `resetUpload()` or `clearUploadStatus()` is called.

### `UploadState` Fields

| Field | Type | Meaning |
|---|---|---|
| `track` | `UploadTrack` | All track data (file path, metadata) |
| `isLoading` | `bool` | True during `upgradeToArtist()` API call |
| `isUploading` | `bool` | True while `uploadTrack()` is in progress |
| `uploadProgress` | `double` | 0.0 to 1.0. Updated at each upload step |
| `error` | `String?` | Non-null when upload or role upgrade fails |
| `successMessage` | `String?` | `'Upload complete! ✓'` on success |
| `waveformLoaded` | `bool` | Set by `setWaveformLoaded()`, not used by progress page |
| `processingState` | `String?` | `null`, `'Processing'`, or `'Finished'` — from server poll |
| `needsRoleUpgrade` | `bool` | True when role check fails inside `uploadTrack()` |

### `UploadNotifier` Key Methods

| Method | What it does |
|---|---|
| `initializeUpload(audioFilePath)` | Sets audio file path, pre-fills title from filename |
| `updateTrackField({...})` | Patches any subset of track fields |
| `updateTrack(UploadTrack)` | Replaces entire track object |
| `setWaveformLoaded(bool)` | Flags waveform as ready (currently not used in active UI) |
| `uploadTrack()` | Full 6-step API upload (role check → POST init → PUT blob → PATCH confirm → PATCH metadata → PATCH artwork → poll) |
| `simulateUpload()` | Fake progress loop (no HTTP calls) — exists but not called by any active page |
| `upgradeToArtist()` | `PATCH /profile/tier` to promote role to artist |
| `resetUpload()` | Wipes entire state back to empty track |
| `clearUploadStatus()` | Resets `isUploading`, `uploadProgress`, `processingState` while preserving track data |
| `clearError()` | Sets `error = null` |
| `clearSuccessMessage()` | Sets `successMessage = null` |

### How UI Reads State

```dart
// watch — rebuild widget on any state change:
final uploadState = ref.watch(uploadProvider);

// read — one-time read, does not rebuild:
final uploadState = ref.read(uploadProvider);

// call notifier methods:
ref.read(uploadProvider.notifier).updateTrackField(...);
```

### Progress Values at Each Step

| Step | `uploadProgress` value |
|---|---|
| Start | 0.0 |
| After role check passed | 0.1 |
| Azure upload begins | 0.10 |
| During Azure PUT (streaming) | 0.10 + (sent/total × 0.65) → max ~0.75 |
| PATCH confirm | 0.80 |
| PATCH metadata | 0.85 |
| PATCH artwork | 0.90 |
| Poll loop runs | stays at 0.90 |
| Upload complete | 1.0 |

---

## G. Waveform Explanation

### Current Status: Placeholder Only

The waveform feature is **not fully implemented** in the active upload flow.

### What Exists

1. **`PlayerTrack.waveform` field** — `lib/features/player/domain/entities/player_track.dart`
   - Type: `List<int>?`
   - Populated from API response in `player_api_service.dart` when tracks are fetched for playback.
   - Used by the full player page to show a waveform if the server returns waveform data.

2. **`UploadState.waveformLoaded` flag** — `lib/features/library/presentation/providers/upload_provider.dart`
   - Type: `bool`, default `false`.
   - `setWaveformLoaded(true)` is called by the orphaned `upload/presentation/pages/upload_page.dart` when an audio file is picked.
   - **Not used by any active UI** — the library `UploadEditPage` and `UploadProgressPage` do not display a waveform.

3. **Placeholder waveform bars** — `lib/features/upload/presentation/pages/upload_page.dart` (ORPHANED)
   - Shows fake waveform: `List.generate(20, (i) => Container(height: 20 + (i % 5) * 10.0, ...))`.
   - This is a visual placeholder only. No real waveform data.

4. **`just_waveform: ^0.0.7` in `pubspec.yaml`**
   - Package is included as a dependency but is not imported or used in any active file.

### Summary

| Aspect | Status |
|---|---|
| Waveform package available | Yes (`just_waveform ^0.0.7`) |
| Waveform generated on upload | No |
| Waveform displayed during upload | No (orphaned file only has a placeholder) |
| Waveform received from server | Yes — `PlayerTrack.waveform` holds it for playback |
| Waveform displayed during playback | Depends on full player UI — data is available |

### Where to Look First

- If asked about waveform during upload: `lib/features/upload/presentation/pages/upload_page.dart` (orphaned) — shows what was intended.
- If asked about waveform during playback: `lib/features/player/domain/entities/player_track.dart` field `waveform`, and `lib/features/player/data/services/player_api_service.dart` where it is parsed from API.

---

## H. Backend / API / Network Integration

### API Client

**File:** `lib/core/network/dio_client.dart`

- Singleton `DioClient`. Base URL: `https://biobeats.duckdns.org/api`.
- Provider: `final dioClientProvider = Provider<DioClient>((ref) => dioClient)`.
- Headers automatically include `Authorization: Bearer {token}` after login.
- Cookies managed by `PersistCookieJar`.
- 401 auto-refresh: hits `POST https://biobeats.duckdns.org/api/auth/refresh` with `refreshToken` from SharedPreferences.

### Upload API Endpoints

All called from `lib/features/library/presentation/providers/upload_provider.dart` → `uploadTrack()`.

#### 1. Initiate Upload
```
POST /tracks/upload
Body: { title, format, size, duration }
Response: { data: { trackId: String, uploadUrl: String } }
```
- `format`: MIME type string (`audio/mpeg`, `audio/wav`, `audio/mp4`, `audio/flac`, `audio/ogg`).
- `size`: file size in bytes.
- `duration`: in **whole seconds** (not milliseconds).

#### 2. Upload to Azure Blob Storage
```
PUT {uploadUrl}   (full URL returned in step 1)
Headers: Content-Type, Content-Length, x-ms-blob-type: BlockBlob
Body: raw binary audio bytes (streamed)
Uses: bare Dio() instance — NOT dioClient
```
- SAS URL handles auth — no Authorization header should be sent.
- Returns `201 Created` or `200 OK` on success.

#### 3. Confirm Upload
```
PATCH /tracks/{trackId}/confirm
Body: none
Response: { data: { permalink: String } }
```

#### 4. Update Metadata (Optional)
```
PATCH /tracks/{trackId}/metadata
Body: { title?, description?, genre?, tags?, releaseDate? }
Only sends fields that are non-null/non-empty
```

#### 5. Upload Artwork (Optional)
```
PATCH /tracks/{trackId}/artwork
Body: FormData { artwork: MultipartFile }
Only runs if coverImagePath != null
```

#### 6. Poll Processing Status
```
GET /tracks/{permalink}
Response: { data: { track: { processingState: "Processing" | "Finished" } } }
Polls every 3 seconds, up to 60 attempts (3 minutes max)
```

### Other Upload-Related API Calls

#### Fetch User's Tracks
```
GET /tracks/my-tracks
File: lib/features/library/presentation/providers/my_tracks_provider.dart
Response: { data: [ { title, artist, genre, description, isPublic, duration, ... } ] }
```

#### Upgrade to Artist Role
```
PATCH /profile/tier
Body: { tier: 'artist' }
File: uploadProvider.notifier.upgradeToArtist()
Also writes 'role' = 'artist' to SharedPreferences on success
```

### Authentication Flow in Upload Context

1. Login writes `accessToken` + `refreshToken` to SharedPreferences.
2. `DioClient` picks up `accessToken` in `init()` and sets `Authorization: Bearer {token}`.
3. All requests to the app backend use this token automatically.
4. Azure PUT step creates a fresh `Dio()` to avoid sending this token to Azure.
5. Role `'artist'` is stored in SharedPreferences key `'role'` after login or after `upgradeToArtist()`.

---

## I. Data Models

### `UploadTrack` — `lib/features/library/domain/entities/upload_track.dart`

| Field | Type | Default | Purpose |
|---|---|---|---|
| `audioFilePath` | `String?` | null | Local device path to audio file |
| `coverImagePath` | `String?` | null | Local device path to cover image |
| `title` | `String` | required | Track title |
| `artist` | `String` | required | Artist name |
| `album` | `String?` | null | Album name (optional, not currently sent to API) |
| `genre` | `String?` | null | Genre string (sent to PATCH /metadata) |
| `tags` | `List<String>` | `[]` | Tags array (sent to PATCH /metadata) |
| `releaseDate` | `DateTime?` | null | Release date (sent to PATCH /metadata as ISO 8601) |
| `isPublic` | `bool` | `true` | Public/private toggle |
| `description` | `String?` | null | Description text (sent to PATCH /metadata) |
| `duration` | `int?` | null | Duration in **milliseconds** (note: API requires seconds — converted in `uploadTrack()`) |
| `processingState` | `String?` | null | Mirrors server: `null`, `'Processing'`, `'Finished'` |

Equatable: all 12 fields are in `props`. Used in `test/features/upload/upload_track_test.dart`.

### `UploadState` — `lib/features/library/presentation/providers/upload_provider.dart`

| Field | Type | Default | Purpose |
|---|---|---|---|
| `track` | `UploadTrack` | empty title+artist | The track being uploaded |
| `isLoading` | `bool` | false | During `upgradeToArtist()` |
| `isUploading` | `bool` | false | During `uploadTrack()` |
| `uploadProgress` | `double` | 0.0 | 0.0–1.0 progress |
| `error` | `String?` | null | Upload/role error message |
| `successMessage` | `String?` | null | Set to `'Upload complete! ✓'` |
| `waveformLoaded` | `bool` | false | Waveform ready flag (unused in active UI) |
| `processingState` | `String?` | null | Server processing state |
| `needsRoleUpgrade` | `bool` | false | Role check failed |

### `PlayerTrack` — `lib/features/player/domain/entities/player_track.dart`

| Field | Type | Purpose |
|---|---|---|
| `id` | `String` | Server-side track ID |
| `title` | `String` | Track title |
| `artist` | `String` | Artist name |
| `audioUrl` | `String` | HTTP URL (HLS/CDN) or local file path |
| `coverUrl` | `String?` | Cover artwork URL |
| `duration` | `Duration?` | Track length |
| `waveform` | `List<int>?` | Waveform data from server |
| `artistId` | `String?` | Artist's user ID for follow/unfollow |

Note: `UploadTrack` and `PlayerTrack` are separate models. `UploadTrack` is for the upload flow. `PlayerTrack` is for playback. They are NOT interchangeable.

### API Request Bodies (Not a class, inline `Map<String, dynamic>`)

**POST /tracks/upload:**
```json
{
  "title": "string",
  "format": "audio/mpeg",
  "size": 12345678,
  "duration": 180
}
```

**PATCH /tracks/{id}/metadata:**
```json
{
  "title": "optional",
  "description": "optional",
  "genre": "optional",
  "tags": ["optional", "array"],
  "releaseDate": "2026-01-01T00:00:00.000Z"
}
```

---

## J. Bug Troubleshooting Guide

### If the upload FAB does nothing

**Where to look first:** `lib/features/library/presentation/pages/library_uploads_page.dart`
- Check `_pickAndUpload()` — the first thing it does is a role check. If role is not `'artist'`, it shows a dialog and returns. The user may be seeing the dialog or it may be failing silently.
- Check `SharedPreferences` key `'role'` — log it to verify the value.
- Check `FilePicker` permissions — on Android, `READ_EXTERNAL_STORAGE` / `READ_MEDIA_AUDIO` may be missing.

### If the audio picker does not open

**Where to look first:**
- `lib/features/library/presentation/pages/library_uploads_page.dart` — `_pickAndUpload()` — the `FilePicker.platform.pickFiles()` call.
- Check platform permissions in `AndroidManifest.xml` / `Info.plist`.
- The `file_picker: ^8.0.0` package is in `pubspec.yaml` — ensure `flutter pub get` was run.
- Check if the `try/catch` is swallowing an exception silently.

### If waveform is missing

**Where to look first:**
- The active upload pages (`UploadEditPage`, `UploadProgressPage`) do NOT display a waveform. There is no waveform in the active upload flow.
- If expected during playback: `lib/features/player/domain/entities/player_track.dart` — `waveform` field. Check if the player API returns this data.
- The `just_waveform` package is available but unused.

### If metadata is not saved

**Where to look first:**
- `lib/features/library/presentation/pages/upload_edit_page.dart` — `_uploadTrack()` at line 197.
- All metadata is written to `uploadProvider` just before navigating. Check `updateTrackField()`.
- The provider is global — state persists until `resetUpload()` is called.
- Check `UploadState.track` fields are not null/empty after the form submission.

### If the upload request fails

**Where to look first:**
- `lib/features/library/presentation/providers/upload_provider.dart` — `uploadTrack()` — the `catch (e)` block at the bottom.
- `error` field in state — the progress page displays it in a red box.
- **Step A (POST /tracks/upload):** Check `dioClient.dio` is initialized (token set), role check passed, `durationSeconds > 0`.
- **Step B (PUT Azure):** Check `uploadUrl` is valid. Check that you're using bare `Dio()`, not `dioClient.dio` — Azure rejects Authorization headers.
- **Step C (PATCH confirm):** Check `trackId` from step A response is correctly extracted: `uploadInitResponse.data['data']['trackId']`.

### If upload progress page is wrong / stuck

**Where to look first:**
- `lib/features/library/presentation/pages/upload_progress_page.dart` — `_uploadStarted` flag.
- If `uploadTrack()` never starts: check `initState()` → `addPostFrameCallback` runs only once (guarded by `_uploadStarted`).
- If progress is stuck at 0: Azure PUT may have failed silently (check `azureResponse.statusCode`).
- If stuck at 90%: polling loop is running. Check `_pollProcessingStatus()` — it will timeout after 3 min.

### If route / navigation breaks

**Where to look first:**
- `lib/core/router/app_router.dart` — verify the exact path strings.
- `/upload` exists (line 274) — leads to `UploadEditPage`.
- `/upload/progress` exists (line 279) — leads to `UploadProgressPage`.
- `/library/uploads` exists (line 222) — leads to `LibraryUploadsPage`.
- `/library/uploads/edit` exists (line 227) — also `UploadEditPage`.
- The route `/upload/edit` does NOT exist. `library/upload_page.dart`'s navigation to `/upload/edit` would fail.

### If backend returns an error

**Where to look first:**
- `lib/core/network/dio_client.dart` — check `validateStatus` (`200–299` only), check interceptors.
- The 401 interceptor auto-refreshes the token — check if `'refreshToken'` is in SharedPreferences.
- For upload-specific errors: `uploadTrack()` catch block wraps all exceptions as `'Upload failed: {e.toString()}'`.
- Azure 403: most common cause is sending Authorization header to Azure SAS URL (must use bare `Dio()`).

### If UI updates but state does not

**Where to look first:**
- `lib/features/library/presentation/providers/upload_provider.dart` — `copyWith()` method.
- Note: `copyWith` for `error` and `successMessage` explicitly passes `null` even if the parameter is null (they always reset). This is intentional but can cause confusion: `state.copyWith(error: null)` clears the error even if you don't pass `error`.
- If watching `uploadProvider` with `ref.read()` instead of `ref.watch()` — `read` does not rebuild the widget.

---

## K. Architecture Map

### Dependency Chain

```
UI (Widgets)
  │
  ├─ LibraryUploadsPage
  │     reads: myTracksProvider (FutureProvider → GET /tracks/my-tracks)
  │     reads: playerProvider
  │     writes: uploadProvider.initializeUpload()
  │     writes: uploadProvider.upgradeToArtist()
  │
  ├─ UploadEditPage
  │     reads: uploadProvider (title, artist, cover, etc.)
  │     writes: uploadProvider.updateTrackField()
  │
  └─ UploadProgressPage
        reads: uploadProvider (progress, error, state)
        writes: uploadProvider.uploadTrack()
        writes: uploadProvider.clearUploadStatus()
        writes: uploadProvider.upgradeToArtist()
        │
        ▼
UploadNotifier (StateNotifier)
  ├─ DioClient (dioClientProvider)
  │     → POST /tracks/upload
  │     → PATCH /tracks/{id}/confirm
  │     → PATCH /tracks/{id}/metadata
  │     → PATCH /tracks/{id}/artwork
  │     → GET /tracks/{permalink}  (polling)
  │     → PATCH /profile/tier
  │
  ├─ Bare Dio()  (NOT dioClient)
  │     → PUT {azureUploadUrl}
  │
  ├─ just_audio AudioPlayer  (duration probe only)
  │
  └─ SharedPreferences  (role check, token reads)
```

### Files Safe to Edit (UI-only)

| File | Risk |
|---|---|
| `upload_edit_page.dart` | Low — only UI, genre list, form layout |
| `library_uploads_page.dart` | Medium — FAB starts upload flow, do not break `_pickAndUpload()` |
| `upload_progress_page.dart` | Medium — UI display, but `initState()` triggers upload |
| `library_page.dart` | Low — menu items only |

### Files Dangerous to Edit

| File | Why dangerous |
|---|---|
| `upload_provider.dart` (library) | Core business logic. Breaking `uploadTrack()` breaks the entire upload. |
| `upload_track.dart` (entity) | Equatable props list must stay in sync with field count — test will break. |
| `app_router.dart` | Changing route paths breaks all `context.push()`/`context.go()` calls. |
| `dio_client.dart` | Auth setup, token refresh. Breaking this breaks all API calls app-wide. |

---

## L. Important Notes / Hidden Gotchas

### 1. Two `upload_provider.dart` Files

There are TWO files named `upload_provider.dart`:
- `lib/features/library/presentation/providers/upload_provider.dart` ← **ACTIVE, REAL**
- `lib/features/upload/presentation/providers/upload_provider.dart` ← **STUB, ORPHANED**

Both define `UploadState`, `UploadNotifier`, and `uploadProvider`. If the stub were ever imported alongside the library version in the same file, there would be a naming conflict. The stub should eventually be deleted.

### 2. Two `upload_progress_page.dart` Files

- `lib/features/library/presentation/pages/upload_progress_page.dart` ← **ACTIVE** (used by router, auto-starts upload in `initState`)
- `lib/features/upload/presentation/pages/upload_progress_page.dart` ← **ORPHANED** (not in router, simpler implementation)

### 3. The Schedule Feature Is Not Wired to the API

`UploadEditPage` has a schedule toggle + date/time picker. These are stored in **local widget state only** (`_isScheduleEnabled`, `_scheduleDate`, `_scheduleTime`). They are NOT written to `uploadProvider`. They are NOT sent to the backend. The "Schedule your release with Artist Pro" card is promotional UI.

### 4. `UploadProgressPage` Auto-Starts the Upload

The upload doesn't start when the user taps "Upload Track" in `UploadEditPage`. It starts when `UploadProgressPage` builds its state in `initState()`. This is a design pattern where the form page only prepares state and navigates, and the progress page is responsible for kicking off the actual work.

### 5. Azure Upload Uses Separate Dio Instance

The `PUT {azureUploadUrl}` step uses `final azureDio = Dio()` — a completely fresh instance with no interceptors, no base URL, no headers. This is intentional. Azure SAS URLs authenticate via the URL query parameters, not headers. Sending `Authorization` or `Cookie` headers to Azure causes a 403 error.

### 6. `UploadTrack.duration` Is in Milliseconds, API Expects Seconds

`UploadTrack.duration` stores milliseconds (matching `just_audio`'s `Duration.inMilliseconds` convention). But `POST /tracks/upload` requires seconds. The conversion happens in `uploadTrack()`: `durationSeconds = (state.track.duration! / 1000).round()`. This is easy to miss.

### 7. `library_page.dart` Uses `/likes` Not `/library/likes`

Line 90 of `library_page.dart`: `context.push('/likes')`. The `/likes` global route exists in `app_router.dart` line 347. However, the shell-nested route is `/library/likes`. Both point to `LibraryLikesPage`. This is an inconsistency — the library page uses the global route which takes the user outside the shell branch.

### 8. `library_uploads_page.dart` Navigates to `/upload` (not `/library/uploads/edit`)

In `_pickAndUpload()`, after file selection: `context.push('/upload')`. This pushes the global `/upload` route (no bottom nav bar) rather than `/library/uploads/edit` (which would stay inside the shell). The upload experience intentionally hides the bottom nav bar during upload.

### 9. `UploadEditPage` Has No Validation

The "Upload Track" button in `UploadEditPage` calls `_uploadTrack()` which does NOT validate that title or artist are non-empty. The upload will proceed with empty fields. The API may or may not reject empty title.

### 10. Polling Can Run for Up to 3 Minutes

`_pollProcessingStatus()` polls every 3 seconds for up to 60 attempts (3 min). During this time, `isUploading` is `false` but `processingState` is set. The progress page correctly shows "Processing on server..." during this phase, and `canPop` remains `false`.

---

## M. Final Quick Revision Sheet

### Most Important File Paths

| File | What it is |
|---|---|
| `lib/features/library/presentation/pages/library_uploads_page.dart` | Upload entry point (FAB) + uploads list |
| `lib/features/library/presentation/pages/upload_edit_page.dart` | Metadata form + "Upload Track" button |
| `lib/features/library/presentation/pages/upload_progress_page.dart` | Progress display + auto-starts upload |
| `lib/features/library/presentation/providers/upload_provider.dart` | ALL upload logic: state + API calls |
| `lib/features/library/domain/entities/upload_track.dart` | Data model (12 fields, Equatable) |
| `lib/features/library/presentation/providers/my_tracks_provider.dart` | Fetches uploaded tracks from server |
| `lib/core/router/app_router.dart` | Route definitions |
| `lib/core/network/dio_client.dart` | HTTP client, auth, token refresh |

### Most Important Routes

| Route | Page |
|---|---|
| `/library/uploads` | `LibraryUploadsPage` — list + FAB |
| `/upload` | `UploadEditPage` — metadata form (no bottom nav) |
| `/upload/progress` | `UploadProgressPage` — upload in progress (no bottom nav) |
| `/library/uploads/edit` | `UploadEditPage` — same class, different route context |
| `/library/uploads/progress` | `UploadProgressPage` — same class |

### Most Important Providers/Functions

| Symbol | File | Purpose |
|---|---|---|
| `uploadProvider` | `library/.../upload_provider.dart` | Global upload state |
| `UploadNotifier.uploadTrack()` | same | The 6-step real upload function |
| `UploadNotifier.initializeUpload()` | same | Sets audio file, pre-fills title |
| `UploadNotifier.updateTrackField()` | same | Patches track metadata |
| `UploadNotifier.upgradeToArtist()` | same | Role upgrade API call |
| `UploadNotifier.resetUpload()` | same | Clears all upload state |
| `UploadNotifier.clearUploadStatus()` | same | Resets progress/state, keeps track data |
| `myTracksProvider` | `library/.../my_tracks_provider.dart` | `GET /tracks/my-tracks` |
| `dioClientProvider` | `core/network/dio_client.dart` | HTTP client |

### Top 10 Likely Discussion Questions

**Q1: Where does the upload start in the codebase?**
> `LibraryUploadsPage._pickAndUpload()` in `library_uploads_page.dart`. The FAB triggers it. First it role-checks, then opens `FilePicker`, then calls `initializeUpload()`, then navigates to `/upload`.

**Q2: Why does the upload use two different Dio instances?**
> Steps A, C, D, E, F use `dioClient.dio` (the app's shared client with Bearer token + cookies). Step B (Azure PUT) uses a bare `Dio()` with no headers. Azure SAS URLs reject `Authorization` and `Cookie` headers — sending them causes 403.

**Q3: When exactly does `uploadTrack()` get called?**
> In `UploadProgressPage.initState()` via `WidgetsBinding.instance.addPostFrameCallback`. NOT in `UploadEditPage`. The edit page only updates state and navigates.

**Q4: What happens if the user is not an Artist?**
> Two role checks exist: (1) in `_pickAndUpload()` before opening the file picker — shows an AlertDialog with an "Upgrade to Artist" button. (2) in `uploadTrack()` inside the notifier — sets `needsRoleUpgrade = true`, which the progress page shows as an orange upgrade box.

**Q5: How is upload progress tracked?**
> `UploadState.uploadProgress` is a `double` from 0.0 to 1.0. It is manually set at each step: 0.10 after POST init, 0.10–0.75 during Azure PUT (via `onSendProgress`), 0.80 after confirm, 0.85 after metadata, 0.90 after artwork, 1.0 after poll finishes.

**Q6: Where is waveform generated or displayed?**
> It is not generated during upload. The `just_waveform` package is in `pubspec.yaml` but unused. The active upload pages have no waveform visualization. The orphaned `upload/presentation/pages/upload_page.dart` has a fake placeholder waveform (static bars). Waveform data can come from the server in `PlayerTrack.waveform`.

**Q7: What does `UploadTrack` contain vs `PlayerTrack`?**
> `UploadTrack` is the upload model: local file paths, metadata form fields, 12 Equatable props. `PlayerTrack` is the playback model: server IDs, CDN URLs, waveform from server, artistId for follow. They are separate and not interchangeable.

**Q8: How does the app know where in the router upload pages live?**
> `app_router.dart` defines two upload entries: (a) global `/upload` and `/upload/progress` outside the `StatefulShellRoute` (no bottom nav), (b) nested `/library/uploads/edit` and `/library/uploads/progress` inside the Library shell branch. The primary flow uses the global routes.

**Q9: What API endpoints are called during upload?**
> Six calls in order: `POST /tracks/upload`, `PUT {azureUrl}`, `PATCH /tracks/{id}/confirm`, `PATCH /tracks/{id}/metadata`, `PATCH /tracks/{id}/artwork`, then `GET /tracks/{permalink}` (polled up to 60 times every 3s).

**Q10: What files would you change if the upload button did nothing?**
> Start at `upload_edit_page.dart` → `_uploadTrack()`. It should write fields to provider and push `/upload/progress`. Then check `upload_progress_page.dart` → `initState()` → `uploadTrack()`. Then check `upload_provider.dart` → `uploadTrack()` → role check first. Then check `dio_client.dart` for network issues.
