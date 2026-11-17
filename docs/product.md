# Clipshelf product spec

This is the source of truth for what Clipshelf does: scope, features, behavior and the keyboard map. Visual design is in [design.md](design.md). Architecture, stack, data model and permissions are in [architecture.md](architecture.md). Project-level decisions (platform, license, distribution, privacy) are in [CLAUDE.md](../CLAUDE.md#decisions) and are not repeated here.

Conventions:
- **MVP**: without it there is no product. **v1**: feature parity. **later**: expensive or niche, after v1.
- `> TODO:` marks behavior we have not settled. `> Decision needed:` marks a choice the maintainer has to make; the text gives a proposal and the tradeoff.

## 1. Scope

Clipshelf is a clipboard manager for macOS 26 and later. It keeps a history of everything the user copies, shows it in a panel at the bottom of the screen, lets the user organize items into boards, search them, edit them and paste them into any app.

### Non-goals

| Out of scope | Note |
|---|---|
| Sync of any kind (iCloud, CloudKit, other devices) | The data layer is local-only. Device attribution and device filters are dropped with it. |
| Shared boards, collaboration, roles | Depends on sync. |
| AI features: suggestions ranked by the target window, on-device language models, MCP server, Writing Tools | May be revisited after v1; not planned. |
| iOS, iPadOS, visionOS apps, keyboard extension, widgets | Mac only. |
| Licensing, trials, subscriptions, paywall, upsell banners | Free and GPL-3.0. |
| Telemetry, analytics, crash-reporting services, remote in-app messages | See the privacy decision in CLAUDE.md. |
| Importing data from other clipboard managers | Not planned. |

## 2. Glossary

| Term | Meaning |
|---|---|
| **Shelf** | The floating panel at the bottom of the screen that shows cards. Opened with the global shortcut or the menu bar item. |
| **Card** | One stored clipboard item: all its pasteboard representations plus metadata (type, title, source app, times). |
| **History** | The default stream of cards, newest first, subject to retention. |
| **Board** | A named, colored, manually ordered collection of cards. Cards on a board are exempt from retention. |
| **Sequence** | A temporary ordered queue of cards that are pasted one after another with ⌘V in the target app. |
| **Target app** | The app that was frontmost when the shelf opened; direct paste goes there. |
| **Representation** | One pasteboard type and its data (plain text, RTF, HTML, PNG, file URL, …). A card keeps all of them. |
| **Own write** | A pasteboard change made by Clipshelf itself (paste, copy, Sequence). Never captured as a new card. |
| **Quick Paste** | Pasting one of the first nine visible cards with modifier + digit. |

## 3. Features

### 3.1 Capture and history

| Feature | Behavior | Priority |
|---|---|---|
| Continuous capture | Detects every pasteboard change and stores it as a card (§4.1). | MVP |
| Full fidelity | Every representation of every pasteboard item is stored and written back on paste, so rich text, HTML and images survive. | MVP |
| Type detection | Text, Link, Image, File / Multiple files, Color, Unknown (§4.2). | MVP |
| Size cap | Oversized representations are dropped one by one (§4.1). | MVP |
| Source app | Each card records the app it was copied from. | MVP |
| Dedupe, re-copy to top | Copying content that already exists moves that card to the top instead of creating a duplicate (§4.3). | MVP |
| Privacy filters | Skip concealed, transient and auto-generated content and ignored apps (§4.1). | MVP |
| Secret detection | Skip text that looks like a password, token or key (§4.1). | v1 |
| Pasteboard access | On macOS versions with pasteboard privacy, detect when access is not granted and explain how to grant it. | MVP |
| Retention | Age-based limit from 1 day to forever (§4.4). | MVP |
| Erase History | Delete all History cards; board cards stay. | MVP |
| Storage summary | Show item count and disk size next to the retention control. | v1 |
| Pause | Stop capturing until resumed. | MVP |
| Pause for a duration | Pause until a chosen time, then resume automatically. | v1 |
| Recover from a damaged store | Move the unreadable store aside to a backup folder and start with an empty one. | v1 |

### 3.2 Shelf and cards

| Feature | Behavior | Priority |
|---|---|---|
| Shelf | Bottom-of-screen panel with one horizontal row of cards, newest on the left, one card always selected. Height is resizable and remembered. | MVP |
| Compact size | Below a height threshold the cards switch to a condensed layout that shows only content. | v1 |
| Cards by type | Each type has its own preview and footer metadata (details in design.md). | MVP |
| Toolbar | Search field, tabs for History and each board, button to add a board, filter control. | MVP |
| Empty states | Distinct states for empty History, empty board, no search results. | MVP |
| Multi-select | Select several cards and act on all of them (§4.12). | MVP |
| Context menu | All card actions in a native menu. | MVP |
| Preview | Space opens a larger preview anchored to the card (Quick Look for files and images). | v1 |
| Open | Open a link in the default browser or a file in its default app; also "Open With" and "Show in Finder". | MVP (Open), v1 (rest) |
| Show in list | From a search result, jump to the card's place in History or its board with surrounding cards visible. Single selection only. | v1 |
| Rename | Give a card a custom title. | v1 |
| Edit | Edit text, link and color cards in place (§4.10). | v1 |
| Image editing | Rotate, remove background. | later |
| New text card | Create a text or link card from scratch. | v1 |
| Duplicate | Make a copy of a card. | v1 |
| Delete with undo | Delete cards; ⌘Z restores them. | MVP |
| Share | System share sheet. | v1 |
| Drag out | Dragging a card into another app inserts it like a paste; images can be dropped as files. | v1 |
| Link previews | Fetch page title, icon and image for links. Opt-in, off by default. One of the two network uses listed in [CLAUDE.md](../CLAUDE.md#decisions). | v1 |
| File thumbnails | Quick Look thumbnails for file cards. | v1 |
| Text in images | Recognize text in image cards on device so search finds it. | v1 |
| Sounds | Optional sounds on capture and paste, our own assets. | v1 |
| Hidden from screen sharing | The shelf is excluded from screen capture unless the user allows it. | MVP |
| Menu bar item | Template SF Symbol with a menu (§6, Menu bar menu). Can be hidden. | MVP |
| Open at login | Register as a login item. | MVP |
| Permission onboarding | First-run explanation for Accessibility and pasteboard access, with links to System Settings. | MVP |

### 3.3 Pasting

| Feature | Behavior | Priority |
|---|---|---|
| Direct paste | Return or double-click pastes the card into the target app (§4.5). | MVP |
| Copy-only mode | Put the card on the clipboard without pasting, by setting or when Accessibility is not granted. | MVP |
| Paste as plain text | Per paste via modifier, or by default via setting. | MVP |
| Quick Paste | Modifier + 1…9 pastes the Nth visible card (§4.6). | MVP |
| Paste several | Paste a multi-selection in one go (§4.12). | v1 |

### 3.4 Sequence

| Feature | Behavior | Priority |
|---|---|---|
| Start a Sequence | From any app with a global shortcut, or from selected cards (§4.7). | v1 |
| Collect | While open, every new copy joins the Sequence. | v1 |
| Paste next | ⌘V in the target app pastes the next card and removes it from the Sequence. | v1 |
| Paste all | One shortcut pastes all remaining cards at once. | v1 |
| Manage | Reorder by drag, remove, undo the last paste or removal, reverse order, plain-text toggle, close and clear. | v1 |

### 3.5 Boards

| Feature | Behavior | Priority |
|---|---|---|
| Create, rename, recolor, reorder, delete boards | §4.8. | MVP |
| Add to Board / Remove from Board | Context menu, drag onto a tab, or for a multi-selection. | MVP |
| Manual order inside a board | Drag to reorder. | MVP |
| Board navigation | Shortcuts for next and previous board. | MVP |

### 3.6 Search

| Feature | Behavior | Priority |
|---|---|---|
| Type to search | Typing in the open shelf searches immediately (§4.9). | MVP |
| Search text in images | Includes recognized text. | v1 |
| Filters | Type, App, Date, Board as tokens in the search field, suggested while typing; a filter browser lists all of them. | v1 |

### 3.7 Integrations

| Feature | Behavior | Priority |
|---|---|---|
| App Intents | Create card, create board, get card at index, get latest card of a type. | v1 |
| URL scheme | Our own scheme to open the shelf, search, create a text card, open settings. | v1 |
| System Spotlight | Index board cards in Spotlight, opt-in. | later |

> TODO: URL scheme name and grammar.

## 4. Behavior rules

### 4.1 Capture

1. A timer polls the general pasteboard's change count; macOS has no change notification. Proposed interval 0.5 s with timer tolerance, then a short coalescing delay so apps that write in several steps produce one card.
   > TODO: tune interval (0.25–0.5 s) and coalescing delay against CPU use.
2. On a change, the capture is dropped if any of these hold, checked in this order:
   1. Capture is paused.
   2. It is an own write: the change count equals the one recorded after our last write, or the pasteboard carries our private marker type.
   3. No frontmost app can be determined.
   4. The frontmost app is in Ignored Apps.
   5. "Ignore passwords and other concealed content" is on and the pasteboard has a concealed type (`org.nspasteboard.ConcealedType`) or a password manager's private type, or the source is a known password manager app.
   6. "Ignore temporary content from other apps" is on and the pasteboard has `org.nspasteboard.TransientType` or `org.nspasteboard.AutoGeneratedType` (plus the older equivalents some apps still write).
   7. (v1) "Ignore passwords and other concealed content" is on and the text matches the secret patterns below.

   Setting labels are owned by [design.md §8](design.md#8-settings-window).
3. Read every pasteboard item, every type, and its data. Drop:
   - volatile or junk types that carry no content (source markers, Microsoft OLE link types, our own marker);
   - any single representation larger than the size cap. If nothing usable is left, drop the capture.
4. Files are stored by reference (file URL), not by content. The app is not sandboxed, so no security-scoped bookmark is needed.
   > TODO: whether to also keep a bookmark or alias so a file that was moved can still be resolved.
5. Detect the type (§4.2), compute the checksum (§4.3), insert or re-copy, record source app and times, then queue thumbnails, text recognition and (if enabled) link preview in the background.
6. Persist the last seen change count so a change made while Clipshelf was not running is captured once at launch and not twice.

**Source app.** The frontmost app at capture time. A copy made through another app's menu bar extra is attributed to the frontmost app.
> TODO: whether `org.nspasteboard.source` (when present) wins over the frontmost app.

**Ignored Apps.** A user-editable list, preset with Apple Passwords. Checked only at capture time; adding an app does not remove its existing cards. Third-party password managers (1Password, Bitwarden, Dashlane, LastPass, Keeper, Enpass, RoboForm, NordPass, Keychain Access) are treated as confidential sources under rule 5 rather than listed.

**Known limit.** Browser extensions of password managers may not mark their copies as concealed. Users can add the browser to Ignored Apps; say so in the settings help text.

**Secret patterns (v1).** Text is treated as confidential when it contains: an assignment whose key is a password, passcode, secret, token, API key, private key or client secret; a JWT; a well-known token prefix (GitHub, Slack, AWS access key, `sk-` style API keys); an HTTP Bearer or Basic credential.
> TODO: confirm false-positive rate on real code snippets; decide whether a match skips the capture or stores the card marked sensitive.

**Size cap.**
> Decision needed: per-representation cap. Proposal: 50 MB. Higher keeps large images and long documents; lower keeps the store small and capture fast.

**Universal Clipboard.**
> TODO: whether content from another device (`com.apple.is-remote-clipboard`) is captured, and how it is attributed.

**Pasteboard access.** At launch and after wake, read the app's pasteboard access behavior. If it is "ask" or "deny", show a one-time explanation with an "Open System Settings…" button. Use pattern detection, not data reads, where only the type is needed.
> TODO: whether polling the change count alone triggers the system prompt on macOS 26.
> TODO: whether macOS 26 has a supported URL that opens the Accessibility and pasteboard-access panes directly; if not, the button opens System Settings and the text says where to go.

### 4.2 Type detection

Applied in order; the first match wins.

| Order | Type | Rule |
|---|---|---|
| 1 | File / Multiple files | Pasteboard has one or more file URLs. One URL → File, several → Multiple files. |
| 2 | Image | Pasteboard has an image representation (PNG, TIFF, JPEG, HEIC, PDF image) and no file URL. |
| 3 | Link | The trimmed plain text is a single URL with no whitespace. |
| 4 | Color | The trimmed plain text matches the hex rule below. |
| 5 | Text | Any plain or rich text. |
| 6 | Unknown | None of the above. Stored and pasteable, shown with a generic preview. |

**Hex color rule.** The whole trimmed string is exactly six hex digits, and either starts with `#` or contains at least one letter A–F (either case).

| Input | Result |
|---|---|
| `#1A2B3C`, `1a2b3c`, `#235442` | Color |
| `235442` (no `#`, digits only, e.g. a one-time code) | Text |
| `#FFF`, `rgb(…)`, `red`, hex inside a sentence | Text |

> TODO: which URL schemes count as Link (proposal: http, https, mailto, ftp, and any scheme with `//`); whether 8-digit hex with alpha counts as Color.

### 4.3 Dedupe and re-copy

- Checksum: a hash over the card's (type, data) pairs, sorted, after dropping volatile types. The same text copied from two apps dedupes; a rich and a plain version of the same text do not.
- If the checksum exists, the existing card moves to the top of History (its "last copied" time is set to now; its creation time stays) and its source app is updated. No new card.
- If the existing card is only on a board, it returns to History and stays on the board.
- Editing a card recomputes its checksum.
> TODO: whether pasting a card from the shelf also moves it to the top of History (own writes are not captured, so this needs an explicit rule).
> TODO: what happens when an edit makes a card identical to another one.

### 4.4 Retention

- Options: 1 Day, 1 Week, 1 Month (default), 1 Year, Forever. Age only; no count limit.
- Age counts from the card's last copied time.
- Purge runs at launch and then hourly; it deletes History cards older than the limit that are not on a board. Board cards that leave History stay on their board.
- Lowering the limit when older cards exist asks for confirmation, states that board cards are kept and that the action cannot be undone. Cancel keeps the old limit.
- Erase History asks for confirmation; it removes all History cards not on a board and takes board cards out of History. Not undoable.
- Payload files no longer referenced by any card are garbage-collected.

### 4.5 Paste mechanics

1. The target app is the app that was frontmost when the shelf opened. Its name appears in "Paste to <App>" menu items.
2. Write the card to the general pasteboard: clear it, write every stored representation (for plain text: only the plain string), add our private marker type, record the resulting change count.
3. Hide the shelf. The shelf never activates Clipshelf, so the target app stays frontmost.
4. If the paste setting is "Paste into the active app" and Accessibility is granted, post a synthesized ⌘V key down/up. Resolve the key code for "V" from the current keyboard layout, and handle layouts that switch to QWERTY while ⌘ is held.
5. If Accessibility is not granted, the first direct paste asks whether to grant it or just copy, with a "don't ask again" option. After declining, Return copies only.
6. If the paste setting is "Copy to the clipboard only", Return copies only and the shelf closes.
7. Play the paste sound if sounds are on.

The pasteboard keeps the pasted content afterwards; the previous clipboard is not restored.

**Plain text.** The plain-text modifier (default ⇧) turns any paste or copy into plain text: ⇧Return, ⇧-double-click, Quick Paste with ⇧. "Paste without formatting by default" makes it the default; there is no inverse modifier.
> TODO: whether holding the modifier when "Paste without formatting by default" is on pastes rich text.

### 4.6 Quick Paste

- While the shelf is open, holding the Quick Paste modifier (default ⌘) shows number badges 1–9 on the first nine visible cards of the current list or search result.
- Modifier + digit pastes that card; adding the plain-text modifier pastes it as plain text.
- Numbers follow what is visible after scrolling, not the absolute start of the list.
> TODO: whether badges should also appear without holding the modifier (accessibility).

### 4.7 Sequence

- **Start from another app.** The Sequence shortcut opens the Sequence panel and synthesizes ⌘C in the frontmost app; the resulting copy becomes the first card. Needs Accessibility.
- **Start from the shelf.** With cards selected, the same shortcut or "Add to Sequence" in the context menu seeds the Sequence with them in shelf order.
- **Collect.** While the panel is open, every captured copy is added. Cards can also be dragged in from other apps or from the shelf.
- **Order.** Each new card goes either to the end of the queue or to its head, depending on "Reverse Order". The head is pasted next.
  > Decision needed: default order. Proposal: copy order (first copied, first pasted), which matches the name and suits users who collect a list top to bottom. Alternative: newest first, which pastes the latest copy next but reverses a collected list.
- **Paste next.** The head card is kept on the pasteboard. When the user presses ⌘V in any app, that card is pasted, removed from the Sequence and the next one is put on the pasteboard. Dragging a card out also removes it. Pasting a card out of order (double-click, context menu) also removes it. When the last card is pasted, the panel closes.
  > TODO: detection mechanism for ⌘V. Prototype a lazy pasteboard data provider (fires when the target app reads the data) first, with a global key monitor as fallback.
- **Paste all.** Pastes all remaining cards at once; text cards are joined with a newline. Clears the Sequence and closes the panel.
- **Plain text.** A toggle in the panel; it persists across Sequences.
- **Undo** restores the last pasted or removed card to its previous position. Close clears the Sequence.
- Sequence cards stay in History; the Sequence itself is not persisted across app restarts.

### 4.8 Boards

- A board has a name, a color and a position among the tabs. Default name "Untitled" if left empty.
- Colors come from the system palette (red, orange, yellow, green, blue, purple, gray).
  > TODO: final palette size and order (see design.md).
- A card belongs to at most one board. Adding it to another board moves it.
- Add to Board keeps the card in History. A board card survives retention and Erase History; after that it exists only on the board.
- Remove from Board takes the card off the board. If it is no longer in History, it is deleted.
- Deleting a board asks for confirmation. Its cards that are still in History stay in History; the rest are deleted.
- Order inside a board is manual (drag). Newly added cards go to the front.
  > TODO: front or end for newly added cards.
- The shelf reopens on the last selected tab.
  > TODO: or always on History.

### 4.9 Search and filters

- Typing while the shelf is focused starts a search; ⌘F focuses the search field. Results update live; one result is always selected; Return pastes it.
- Scope: History and all boards together, regardless of the current tab. Results show which board a card is on.
  > TODO: confirm global scope vs current tab.
- Matched fields: title, text content, URL and page title, file names, source app name, recognized image text (v1).
- Case- and diacritic-insensitive, word-prefix matching. Ordered newest first. Matches are highlighted.
- Filters (v1): Type, App, Date (today, yesterday, last 7 days, last 30 days, custom range), Board. Typing a word that matches a type or app name offers it as a filter token. Filters combine with AND. Pressing ⌘F again while the field is focused opens a browser of all filters.
- Tab moves focus between the search field and the results.
- Esc clears the search first, then closes the shelf on the next press.

### 4.10 Editing (v1)

- **Rename:** ⌘R or click on the card title. An empty title removes the custom title; the card shows its type label again.
- **Edit:** ⌘E opens an editor for the card type.
  - Text: rich editing with bold, italic, underline, strikethrough; live character, word and line counts.
  - Link: edit the URL; re-detect type on save.
  - Color: system color panel.
  - Image and file cards: rename only (image editing later).
- Save replaces the card's content in place, keeps its position and board, and updates its modified time. Discard leaves it unchanged. Edits never touch the system clipboard.
- **New text card:** ⌘N opens an empty text editor; on save the card is added to the top of History, or to the current board when a board tab is active.

### 4.11 Deleting

- Delete (⌫) removes the selected cards. One card is deleted immediately; several ask for confirmation with the count.
- ⌘Z undoes the last delete while the shelf is open.
  > TODO: whether undo also covers Add to Board, Remove from Board, rename and edit.
- Deleting in History removes the card from History; deleting on a board removes it from the board. A card is removed from the store when it is in neither.
  > TODO: confirm that Delete on a board should not also remove the card from History.

### 4.12 Multi-select

- ⌘-click toggles, ⇧-click extends, ⇧← / ⇧→ extend from the keyboard, ⌘A selects all in the current list. The toolbar shows the selected count and a way to deselect.
- Actions on a selection: paste, paste as plain text, copy, add to board (or move to another board), delete, add to Sequence, share, drag out. Rename, edit, preview and show-in-list need a single card.
- Paste several:
  - all text: joined with a newline into one paste;
  - all files: one pasteboard write with all file URLs;
  - mixed: one pasteboard write with one item per card.
  > Decision needed: order of a multi-paste. Proposal: oldest first (the order the user copied them). Alternative: selection order, which is more flexible but invisible in the UI.

### 4.13 Shelf window behavior

- Opens on the display that contains the mouse pointer; it is not tied to a display.
- Joins the active Space and appears above full-screen apps without switching Spaces.
- Never activates Clipshelf or steals frontmost status from the target app, but takes keyboard focus so the shortcuts work.
- Closes on: Esc (when search is empty), a second press of the global shortcut, a successful paste or copy from the shelf, and focus loss.
- **Focus loss:** clicking another app or window, or switching apps, closes the shelf. Closing is suspended while one of our own sheets, menus, popovers, the preview, the editor or the color panel is open.
  > TODO: option to keep the shelf open after paste (requested by users of comparable apps).
- Height is resizable by dragging the top edge and is remembered.
  > TODO: one height for all displays or per display.
- Excluded from screen sharing and screenshots unless "Show the Shelf in screenshots and screen sharing" is on.
- The Sequence panel is a separate small floating panel that the user can move; its position is remembered. It follows the same Space and full-screen rules.

## 5. Keyboard map

### Global (customizable)

| Action | Default | Priority |
|---|---|---|
| Show / hide the shelf | ⇧⌘V | MVP |
| Start Sequence (copies the current selection in the frontmost app) | ⇧⌘C | v1 |
| Paste next Sequence card | ⌘V (the system shortcut; not registered by us) | v1 |
| Paste all Sequence cards | ⌃⌥⌘V | v1 |

> Decision needed: default shelf shortcut. Proposal: ⇧⌘V. It is what users of comparable apps expect and Spotlight's own clipboard view does not use it. Tradeoff: in Chrome, Slack, Google Docs and many other apps ⇧⌘V is "Paste and Match Style", and a global hotkey takes it away from them. Alternatives: ⌥⌘V (taken by Finder for "Move Item Here"), ⌃⌘V (rarely used, less memorable).

> Decision needed: default Sequence shortcut. Proposal: ⇧⌘C. Tradeoff: it shadows ⇧⌘C in Finder (Go to Computer), in browsers (inspect element) and in some editors.

### In the shelf

| Action | Keys | Priority |
|---|---|---|
| Close / clear search | Esc | MVP |
| Previous / next card | ← / → | MVP |
| First / last card | ⌘↑ / ⌘↓ | MVP |
| Extend selection | ⇧← / ⇧→, ⇧-click, ⌘-click | MVP |
| Select all | ⌘A | MVP |
| Paste (or copy in copy-only mode) | Return, double-click | MVP |
| Paste as plain text | ⇧Return, ⇧-double-click | MVP |
| Quick Paste Nth card | ⌘1…⌘9 | MVP |
| Quick Paste Nth card as plain text | ⇧⌘1…⇧⌘9 | MVP |
| Copy to clipboard | ⌘C | MVP |
| Open link / file | ⌘O | MVP |
| Delete | ⌫ | MVP |
| Undo | ⌘Z | MVP |
| Search | type, or ⌘F | MVP |
| Filter browser | ⌘F while the search field is focused | v1 |
| Move focus between search and cards | Tab; ↓ from the search field | MVP |
| Previous / next tab (History, boards) | ⌘← / ⌘→ (customizable) | MVP |
| New board | ⇧⌘N | MVP |
| Pause / resume capture | ⌘T | MVP |
| Preview | Space | v1 |
| Rename | ⌘R | v1 |
| Edit | ⌘E | v1 |
| New text card | ⌘N | v1 |
| Show in list | ⌘G | v1 |
| Settings | ⌘, | MVP |
| Quit | ⌘Q | MVP |

Note: first / last card use ⌘↑ / ⌘↓ because ⌘← / ⌘→ switch tabs. Space types a space while the search field has focus; it previews only when the cards have focus.

### In the Sequence panel

| Action | Keys |
|---|---|
| Remove selected card | ⌫ |
| Undo last paste or removal | ⌘Z |
| Close and clear | Esc |

### Shortcut recorder rules

- Reject a combination already used by another Clipshelf shortcut, by a menu item, or by a system shortcut, and say which.
- Warn that shortcuts using only ⌥ as a modifier may not work reliably.
- A cleared shortcut stays cleared across restarts. If both the shelf shortcut and the menu bar item are off, the shelf can still be opened through the URL scheme or by launching the app again.
- "Restore Defaults" asks for confirmation.

## 6. Settings

Content and defaults only; layout and exact label wording are in [design.md §8](design.md#8-settings-window).

### General

| Setting | Options | Default |
|---|---|---|
| Open at login | on / off | off; offered during onboarding |
| Show in menu bar | on / off | on |
| Clicking the menu bar item | Show menu / Open shelf | Show menu |
| Sound effects | on / off | off |
| Keep history | 1 Day, 1 Week, 1 Month, 1 Year, Forever | 1 Month |
| Storage summary | item count and size (read-only, v1) | — |
| Erase History | button with confirmation | — |
| Paste behavior | Paste into the active app / Copy to the clipboard only | Paste into the active app |
| Paste without formatting by default | on / off | off |
| Accessibility status | granted / not granted, button to open System Settings | — |
| Pasteboard access status | shown only when access is not "allow" | — |

### Shortcuts

| Setting | Default |
|---|---|
| Show / hide the shelf | ⇧⌘V (pending decision) |
| Start Sequence | ⇧⌘C (pending decision) |
| Paste all Sequence cards | ⌃⌥⌘V |
| Next board / Previous board | ⌘→ / ⌘← |
| Quick Paste modifier | ⌘ (one of ⌘ ⌃ ⌥) |
| Plain text modifier | ⇧ (one of ⇧ ⌘ ⌃ ⌥, must differ from the Quick Paste modifier) |
| Restore Defaults | button with confirmation |

### Privacy

| Setting | Options | Default |
|---|---|---|
| Ignored apps | list with add / remove | Apple Passwords |
| Ignore passwords and other concealed content | on / off | on |
| Ignore temporary content from other apps | on / off | on |
| Fetch link previews | on / off, with a note that fetching may trigger one-time or tracking links | off |
| Show the Shelf in screenshots and screen sharing | on / off | off |
| Recognize text in images | on / off (on device) | on |

> TODO: whether file thumbnails need a toggle (they read file contents through Quick Look).

### Menu bar menu

This is the item list; grouping and wording are in [design.md §7](design.md#7-menu-bar-extra).

- Open Shelf · New Text Card · Start Sequence
- Pause Capture for 15 minutes, 1 hour, 8 hours, until tomorrow, or until resumed / Resume Capture; while paused, the time capture resumes
- Settings… · Check for Updates… (always manual, see [CLAUDE.md](../CLAUDE.md#decisions)) · About Clipshelf
- Clipshelf Help · Report an Issue
- Quit Clipshelf

## 7. Open questions

- > TODO: polling interval and coalescing delay (§4.1).
- > TODO: priority of `org.nspasteboard.source` over the frontmost app (§4.1).
- > TODO: Universal Clipboard content: capture or skip, and attribution (§4.1).
- > TODO: secret patterns: skip or mark, false-positive rate (§4.1).
- > TODO: pasteboard privacy on macOS 26: what triggers the system prompt (§4.1).
- > TODO: direct System Settings links for Accessibility and pasteboard access (§4.1).
- > TODO: bookmark or alias for moved files (§4.1).
- > TODO: URL schemes that count as Link; 8-digit hex (§4.2).
- > TODO: does pasting from the shelf move the card to the top of History (§4.3).
- > TODO: edit that makes a card identical to another (§4.3).
- > TODO: plain-text modifier when "Paste without formatting by default" is on (§4.5).
- > TODO: how to detect ⌘V for Sequence advance (§4.7).
- > TODO: board palette; where newly added cards go; which tab the shelf reopens on (§4.8).
- > TODO: search scope: global or current tab (§4.9).
- > TODO: undo scope beyond delete (§4.11).
- > TODO: Delete on a board vs History (§4.11).
- > TODO: keep-shelf-open option; per-display height (§4.13).
- > TODO: drag-out formats for several cards and for images (file vs image data).
- > TODO: compact-size threshold (with design.md).
- > TODO: URL scheme name and grammar (§3.7).
