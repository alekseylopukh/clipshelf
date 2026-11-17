# Clipsy UI and visual design

This is the source of truth for how Clipsy looks. Behavior, features and the keyboard map live in [product.md](product.md); window plumbing, permissions and data live in [architecture.md](architecture.md). Product decisions (macOS 26+, no sync, no brand chrome) are in [CLAUDE.md](../CLAUDE.md#decisions).

Terms used here:

| Term | Meaning |
|---|---|
| Shelf | The floating panel that shows clipboard items |
| Card | One item on the Shelf |
| History | The default, time-ordered stream of everything copied |
| Board | A named, colored collection of Cards |
| Sequence | A queue of Cards pasted one after another |

Values marked "proposed" are starting points to tune on real hardware, not measured facts.

---

## 1. Design principles

1. **Looks like Apple shipped it.** System controls, SF Symbols, system text styles, semantic colors, the user's accent color. If AppKit or SwiftUI has a control for it, we use that control. No custom fonts, no brand colors, no illustrations.
2. **Liquid Glass is for controls, not content.** The Shelf container, the top bar, floating badges and the Sequence header are glass. Cards are content: opaque, readable, and they never sit in glass of their own.
3. **Content first.** A Card spends its area on the preview. Metadata is small, secondary and neutral.
4. **Color means something or it isn't there.** The only colors in the UI are the accent color (selection, primary action), Board colors (identity of a Board) and the content itself (images, color swatches, link thumbnails).
5. **Keyboard is a first-class input.** Every action reachable by pointer is reachable by keyboard, and focus is always visible.
6. **Respect system settings.** Light/Dark, accent color, Reduce Motion, Reduce Transparency, Increase Contrast, Liquid Glass appearance, Dynamic Type where macOS supports it.

### Visual choices we made

| Rejected option | Clipsy | Why |
|---|---|---|
| Saturated colored header band per Card (tinted by source app or type) | Neutral header: app icon, type label, relative time in secondary label color | HIG asks for sparing color and monochrome chrome; a rainbow of headers competes with content and with Board colors. The source app stays identifiable through its real icon. |
| Glass on Cards at every size | Glass only on the Shelf container and controls | HIG: no Liquid Glass in the content layer. Opaque Cards keep text contrast stable over any wallpaper. |
| Colored Board tabs | Board name with a small colored dot | Same information, less chroma; reads like Finder tags. |
| Custom animated menu bar icon | Template SF Symbol with a system symbol effect | Matches every other menu bar extra; adapts to the menu bar appearance. |
| In-app promotional banners | None. Only system alerts where a permission is actually missing | No nudges, no upsell. |
| Brand-tinted Sequence window | Plain glass panel with system rows | First-party look. |

An optional faint tint (8–12% opacity) of the source app's icon color behind the Card header is not part of v1; it is listed under Later in [roadmap.md](roadmap.md#later-not-scheduled).

---

## 2. Shelf

### Placement and size

| Aspect | Design |
|---|---|
| Edge | Bottom of the screen, centered horizontally. Bottom only in v1. |
| Inset | Floats like the Dock: inset 8 pt from the bottom and side edges of the visible frame, with a soft system shadow. Never covers the menu bar. Respects the Dock: placed above it when the Dock is at the bottom and visible. |
| Corners | 36 pt, concentric with the Cards at the 16 pt inner padding. Inner elements use concentric radii; see [Metrics](#metrics). |
| Width | Full width of the visible frame minus the insets. |
| Height | User-resizable by dragging the top edge; one remembered height for all displays ([WD-13](roadmap.md#working-defaults-for-open-todos)). Range: from one compact row (160 pt) to 40% of the visible height; default 300 pt ([WD-22](roadmap.md#working-defaults-for-open-todos)). |
| Compact mode | When a regular Card would be under 150 pt tall ([WD-15](roadmap.md#working-defaults-for-open-todos)), Cards switch to a condensed layout: the header collapses to a 20 pt app icon and the time, the footer is hidden and the body fills the rest. Compact Cards are 4:3 instead of square so the time fits next to the icon. |
| Display | Opens on the display that holds the pointer. Moves with the user to the active Space and appears over full-screen apps. |

### Metrics

One radius system and an 8 pt grid (12 pt is the one half step, inside Cards). Every value lives in `DesignTokens`.

| Metric | Value | Rule |
|---|---|---|
| Screen inset | 8 pt | `shelfInset` |
| Shelf padding | 16 pt | `shelfPadding`: top, sides and bottom; the gap between the top bar and the Cards is the same 16 pt |
| Card gap | 16 pt | `cardSpacing` = `shelfPadding`, so gaps between Cards equal the outer insets |
| Card radius | 20 pt | `cardCornerRadius` |
| Shelf radius | 36 pt | `shelfCornerRadius` = Card radius + Shelf padding (concentric) |
| Card content inset | 12 pt | `cardContentInset`, on all four sides |
| Card inner radius | 8 pt | `cardInnerCornerRadius` = Card radius − content inset. Body previews (link image, color swatch, image) clip to `ConcentricRectangle` against the Card's `containerShape`, with this as the minimum |
| Selection ring | 3 pt (4 pt with Increase Contrast), 2 pt gap | Radius = Card radius + gap + width, so the ring is concentric outside the Card |
| Quick-paste badge | 20 pt, inset 10 pt | Inset = Card radius − badge radius, so the badge circle is concentric with the corner |
| Top bar controls | 28 pt tall | Large control size; icon-only buttons are 28 pt circles (16 pt glyph box), the search field is a 28 pt capsule |
| Header icon | 32 pt regular, 20 pt compact | 32 pt is a native app icon size, recognizable at a glance; its squircle corner (~7 pt) matches the 8 pt inner radius |
| Header/body/footer spacing | 8 pt regular, 4 pt compact | `spacingMedium` / `spacingSmall` |
| Text fade | 16 pt | `cardFadeHeight` |

Liquid Glass on the Shelf is a background layer, not a wrapper: wrapping the Cards in `.glassEffect` gave their text the glass's adaptive (vibrant) foreground, which turned Card text dark on dark Cards. Content outside the panel shape is clipped to it, so a Card scrolled under a rounded corner does not poke out.

### Snapshot harness

`scripts/snapshots.sh [dir]` renders the Shelf offscreen to `.build/snapshots` (or `dir`): `shelf-{regular,compact}-{light,dark}.png`, 1920 pt wide at the backing scale. It runs the `ShelfSnapshotTests` suite in `ShelfUITests`, which is skipped unless `CLIPSY_SNAPSHOTS` names the output folder, so `scripts/build.sh test` never renders.

- Fixture: eight made-up Cards (`SnapshotFixtures`: text, rich text, link with preview image, color, code, image, file, three files) and three Boards. Images and files are generated into a temporary folder; app icons come from system apps. No clipboard data is read.
- It hosts `ShelfContainerView` in a borderless `NSWindow` that is never ordered in, so nothing appears on screen, and captures it with `cacheDisplay`.
- Liquid Glass is composited by the window server and does not render offscreen. The harness draws a material stand-in for the Shelf, and glass buttons in the top bar show only their labels. Check glass in the running app.

Left, right and top edges (vertical layout) are not part of v1; they are listed under Later in [roadmap.md](roadmap.md#later-not-scheduled).
Placement uses the display's visible frame, so an auto-hidden Dock is not avoided ([WD-22](roadmap.md#working-defaults-for-open-todos)).

### Behavior as the user sees it

- Opens with the global shortcut (see [product.md](product.md)) or from the menu bar extra. The frontmost app keeps its focus and text cursor; the Shelf takes keyboard input without activating Clipsy's menu bar.
- Closes on Esc, on the shortcut again, after a paste, or when the user clicks outside it. It stays open while one of its sheets (such as an editor) is attached, or while it or one of its child windows (a popover, the Quick Look preview) has keyboard focus, and closes when focus leaves both (see [product.md §4.13](product.md#413-shelf-window-behavior)).
- Hidden from screenshots and screen sharing by default (setting in Privacy).
- One Card is always selected while the Shelf has items; on open, the newest Card in the current view is selected.

### Motion

| Event | Default | Reduce Motion |
|---|---|---|
| Open | Spring rise from just below the bottom edge plus glass materializing (opacity and scale ~0.98→1) | Crossfade only |
| Close | Reverse of open, faster | Crossfade only |
| Card inserted at front | Existing Cards slide right; new Card fades and scales in | Crossfade |
| Card deleted | Neighbors close the gap | Instant reflow |
| Board switch | Content crossfades; top-bar selection morphs between capsules (`glassEffectID`) | Crossfade, no morph |
| Compact ↔ regular | Animated layout change | Instant |

Durations: system spring defaults. We set no custom timing curves unless testing shows a need.

---

## 3. Cards

### Anatomy

A Card is a rounded rectangle with an opaque fill (`controlBackgroundColor` or the SwiftUI secondary background), a hairline `separatorColor` border, and the system Card shadow when lifted. Square in regular mode, 4:3 in compact mode. Metrics are in [§2 Metrics](#metrics).

| Part | Contents | Style |
|---|---|---|
| Header | Source app icon (32 pt, centered on the two text lines, like a two-line list row); title if the user renamed the Card, else the type label; relative time ("2 min ago") below it | Title or type label `.headline`, so every header has the same height; time `.caption` in secondary label color; digits monospaced |
| Body | Type-specific preview (table below) | Clipped to the Card's inner radius |
| Footer | Type-specific metadata | `.caption`, secondary label color (tertiary was too faint for 4.5:1), single line, truncated |
| Board marker | When showing search results from all of History and Boards: the Board's colored dot next to the time | Board color, 6–8 pt dot (proposed) |

### Per-type layouts

| Type | Body | Footer |
|---|---|---|
| Plain text | Text from top-left, `.body`, as many lines as fit, tail-truncated with a fade | Character count |
| Rich text | Rendered with its own fonts and colors, scaled to the system body size; colors that fail contrast on the Card fill fall back to label color | Character count |
| Code-like text | Plain text heuristically detected as code gets SF Mono (`.monospaced()`); no syntax colors. Not a separate type | Line count |
| Link | Link preview image (when previews are on) filling the top of the body; page title below in `.callout` semibold. Without a preview: large site favicon or `link` symbol, centered | Host name, head-truncated URL |
| Image | Image aspect-fit on a neutral fill; checkerboard behind transparency | Pixel dimensions, without grouping separators ("1600 × 1000") |
| File | Quick Look thumbnail or file icon, centered | File name, middle-truncated |
| Multiple files | Up to three stacked thumbnails, slightly fanned | "N files" and total size |
| Color | Swatch filling the body, with the value overlaid on a small glass capsule for legibility | Value in the copied format (hex, rgb) |
| Unknown | Generic `questionmark.square.dashed` symbol, short note that the item can still be pasted | Type identifier, if useful |

Details such as rich text scaling, the contrast threshold and the link body without a preview follow [WD-32](roadmap.md#working-defaults-for-open-todos); link previews follow [WD-40](roadmap.md#working-defaults-for-open-todos).

### States

| State | Look |
|---|---|
| Rest | Opaque fill, hairline border |
| Hover | Slight lift (shadow strengthens); no color change |
| Selected | Accent-colored 3 pt ring, 2 pt outside the Card at a concentric radius, slight lift (scale 1.02) |
| Multi-selected | Each selected Card gets the ring; a count ("3 selected") appears in the top bar |
| Keyboard focus without selection change | Same as Selected; there is only one focus indicator |
| Being dragged | System drag image; the source Card dims |
| Pasted (Sequence) | Not shown on the Shelf; see §6 |

### Quick-paste badges

- While the quick-paste modifier is held (see [product.md](product.md)), the first nine visible Cards show a small glass capsule with the number (1–9) at the top-trailing corner.
- Badges appear and disappear with a short fade; with Reduce Motion, instantly.
- Numbers count from the first visible Card, not the first Card in History.

---

## 4. Top bar

A single row at the top of the Shelf, inside one `GlassEffectContainer` so its capsules merge and morph.

Order, leading to trailing:

1. **Search field.** Capsule search field with a magnifying-glass symbol and placeholder "Search". Typing anywhere on the Shelf starts a search. Active filters show as tokens inside the field.
2. **Filters button** (`line.3.horizontal.decrease`). Opens a popover with sections Type, App, Date, Board. Choosing a value adds a token. Pressing the search shortcut a second time also opens it.
3. **Board switcher.** Horizontally scrolling row of capsules: "History" first (symbol `clock`), then each Board (colored dot + name). The selected one uses the prominent glass style tinted with the accent color. Boards reorder by drag; dropping a Card on a capsule adds it to that Board.
4. **New Board button** (`plus`).
5. **More menu** (`ellipsis`): New Text Card, Start Sequence, Pause/Resume capture, Settings…

While search is active, the Board switcher stays visible. Selecting a Board clears the search and shows that Board ([product.md §4.9](product.md#49-search-and-filters)). Matches in a Card's title and text are highlighted with the system find-highlight color.

### Board colors

System colors only, so they adapt to light/dark and Increase Contrast: red, orange, yellow, green, blue, purple, gray (the Finder tag set). Pink is left out because it is hard to tell apart from red. The color picker in the New/Edit Board sheet is a row of these swatches, not a free color well.

Working default [WD-9](roadmap.md#working-defaults-for-open-todos): every Board has a color; there is no "no color".

### Empty states

Use `ContentUnavailableView` centered in the Card area. Our own wording (proposed):

| Situation | Symbol | Title | Description |
|---|---|---|---|
| History empty | `clipboard` | No Clipboard History | Copy something and it shows up here. |
| Board empty | `square.stack` | This Board Is Empty | Drag Cards here or use "Add to Board". |
| No search results | `magnifyingglass` | No Results | Try a different search or remove a filter. |
| Capture paused | `pause.circle` | Capture Paused | A Resume button. |

---

## 5. Context menu, Quick Look, editing

### Card context menu

Native `NSMenu` with SF Symbols on items and section separators. Items that do not apply to the selection are hidden, not disabled. Order:

| Section | Items |
|---|---|
| Paste | Paste to *App* (`arrow.down.doc`), Paste as Plain Text (`textformat`) |
| Copy | Copy (`doc.on.doc`), Copy as Plain Text |
| Open | Open (links, files), Open With ▸ (files), Show in Finder (files) |
| Organize | Add to Board ▸ (list of Boards + New Board…), Remove from Board (inside a Board), Add to Sequence |
| Item | Quick Look (`eye`), Show in List (search results only), Edit… (`pencil`), Rename… , Duplicate |
| Share | Share… (`square.and.arrow.up`), opens the system share picker at the Card, like Share… in Finder |
| Destructive | Delete (`trash`, destructive role) |

With several Cards selected, the menu shows only actions that work on many: Paste, Paste as Plain Text, Copy, Add to Board, Add to Sequence, Share, Delete.

Inside a Board, Delete is hidden and Remove from Board takes its place, because Delete on a Board only removes the Card from it ([WD-12](roadmap.md#working-defaults-for-open-todos)).

### Quick Look

- Space toggles a preview anchored to the Card under the keyboard cursor, as an `NSPopover` with the system's glass background. Esc closes the preview before it clears the search or closes the Shelf.
- Files use `QLPreviewView`; a file that was moved or deleted shows "File Not Found" with its name. Several files show a list of their names with Quick Look thumbnails.
- Images use our own image view (decoded at up to 2048 px, checkerboard behind transparency): `QLPreviewView` needs a file, and image Cards keep their data in the store, so a temporary copy would put clipboard data outside it.
- Text, rich text, links and colors use our own read-only SwiftUI views: selectable text (rich text keeps the Card's styling rules), the link's title or host with the full URL, and a large swatch with Hex, RGB and HSL values. Details follow [WD-49](roadmap.md#working-defaults-for-open-todos).
- Arrow keys move the selection and the preview follows.

Prototype result (T8.1): the popover uses `.applicationDefined` behavior, is anchored to an invisible view behind the cursor Card, and hands key status back to the Shelf after it opens and after it closes while key, so Space, arrows and Esc keep reaching the Shelf. When a click in the preview (selecting text, scrolling a PDF) makes the popover key, it forwards every key without ⌘ to the Shelf, Esc included, and keeps ⌘ shortcuts so ⌘C copies the selected text. The Shelf stays open while the popover or another child window is key and closes when focus leaves both; the popover's own loss of key status runs the same check as the panel's. This builds and the previews render offscreen in light and dark, but the live behavior inside the non-activating panel was not run by the agent; it is a human check of T8.1.

> TODO: compare against `QLPreviewPanel` (the Finder-style floating panel) in practice; the popover is chosen because it works inside a non-activating panel, but the system panel may feel more native.

### Edit sheet

- Opens as a sheet attached to the Shelf. Working default ([WD-48](roadmap.md#working-defaults-for-open-todos)): no standalone window; the sheet is never taller than the Shelf, and the text area shrinks to fit.
- Toolbar per type, using system controls:
  - Text: Bold, Italic, Underline, Strikethrough as a segmented control (⌘B, ⌘I, ⌘U); character/word/line counts in the bottom bar; an inline error next to the buttons.
  - Link: URL field and optional title field.
  - Color: `ColorPicker` / system color panel plus a format picker (Hex, RGB) and a value field.
  - Link and color editors are grouped forms with Cancel (Esc) and Save (Return); the form scrolls when the Shelf is shorter than the sheet.
  - Image (later): rotate left/right.
- Buttons: Cancel (Esc) and Save (Return with ⌘ in text editors), standard placement.
- Rename uses a small popover with a single text field; empty name clears the title.

---

## 6. Sequence

A separate floating panel, independent of the Shelf, so the user can keep working in the target app.

| Aspect | Design |
|---|---|
| Window | Small non-activating utility panel, glass background; proposed width ~280 pt, height grows with rows up to a limit, then scrolls. Draggable; position remembered. |
| Header | Title "Sequence" with `list.number` symbol; trailing buttons: Undo (`arrow.uturn.backward`), More (`ellipsis`), Close (`xmark`). |
| More menu | Reverse Order, Paste All, Paste as Plain Text (checkmark toggle), Clear |
| Rows | Opaque content rows, one per item: one or two lines of preview, trailing app icon or type symbol. The next row to paste carries a small accent-colored marker. |
| Reorder / remove | Drag to reorder; hover shows a remove button; Delete key removes the selected row. |
| Paste feedback | The pasted row slides out; the next row gets the marker. With Reduce Motion, it disappears instantly. |
| Empty state | Short line in secondary color telling the user to copy items or drag Cards here (own wording). |
| End | After the last item is pasted, the panel fades out. |

---

## 7. Menu bar extra

- Template SF Symbol: `clipboard` normally, `pause.circle` style variant (or `clipboard` with a slash) while paused. A brief `.bounce` symbol effect on each capture; none with Reduce Motion.
- Shown by default; hidden with a Settings toggle. If hidden, the global shortcut still works and launching the app again opens Settings.
- Click shows a menu (per HIG). An opt-in setting makes a left click open the Shelf instead, with the menu on right-click / Control-click.

Menu contents: the items and pause durations are set in [product.md §6](product.md#menu-bar-menu); this table sets grouping and wording.

| Group | Items |
|---|---|
| Main | Open Shelf (shows the shortcut), New Text Card, Start Sequence |
| Capture | Pause Capture ▸ (For 15 Minutes, For 1 Hour, For 8 Hours, Until Tomorrow, Until Resumed) / Resume Capture; when paused, a disabled line with the resume time in the user's locale time format |
| App | Settings… (⌘,), Check for Updates…, About Clipsy |
| Help | Clipsy Help (opens the project docs), Report an Issue |
| Quit | Quit Clipsy (⌘Q) |

Decided (T6.4): `clipboard` normally and `pause.circle` while paused, swapped with the `.replace` content transition. SF Symbols on macOS 26 has no clipboard pause badge.

Decided (T7.3): the disabled line reads "Paused until 15:45", in the locale's short time format, with the abbreviated weekday when the resume time is not today. Until Resumed shows no line.

---

## 8. Settings window

SwiftUI `Settings` scene with a toolbar `TabView`. Each pane is a `Form` with `.formStyle(.grouped)`. Window title equals the pane name; the last pane is restored; minimize and zoom disabled. Opens with ⌘, from the Shelf or the menu bar menu. No Sync pane.

### General

| Control | Type |
|---|---|
| Open at login | Toggle (`SMAppService`) |
| Show in menu bar | Toggle |
| Click on menu bar icon opens the Shelf | Toggle (disabled when the icon is hidden) |
| Sound effects | Toggle |
| Paste behavior | Radio group: "Paste into the active app" / "Copy to the clipboard only" |
| Paste without formatting by default | Toggle |
| Accessibility status | Status row (granted / not granted) with "Open System Settings…" button when missing |
| Keep history for | Slider with tick marks: 1 Day, 1 Week, 1 Month, 1 Year, Forever |
| Storage | Row with secondary value text: card count and disk size, for example "1,234 cards, 56.7 MB" |
| Erase History… | Button, destructive confirmation alert; Board contents are kept |

### Shortcuts

| Control | Type |
|---|---|
| Open Shelf | Shortcut recorder |
| Start Sequence | Shortcut recorder |
| Paste All Sequence Cards | Shortcut recorder |
| Next Board / Previous Board | Shortcut recorders |
| Quick paste modifier | Pop-up: ⌘ / ⌥ / ⌃ |
| Plain text modifier | Pop-up: ⇧ / ⌥ / ⌃ / ⌘ |
| Restore Defaults | Button with confirmation |

The recorder rejects combinations already used by the app, by a menu item or by the system. A conflict with another Clipsy shortcut is shown inline below the field; a menu item or system conflict is shown in the recorder's own sheet (WD-36 in the roadmap).

### Privacy

| Control | Type |
|---|---|
| Ignore passwords and other concealed content | Toggle, on by default |
| Ignore temporary content from other apps | Toggle, on by default |
| Ignored apps | `List` with +/− buttons below (system app picker); Passwords is pre-added |
| Fetch link previews | Toggle with a footnote that it makes a network request per link and may trigger one-time links; off by default (network use: [CLAUDE.md](../CLAUDE.md#decisions)) |
| Recognize text in images | Toggle (on-device; makes images searchable) |
| Show the Shelf in screenshots and screen sharing | Toggle, off by default |
| Clipboard access status | Status row for the system pasteboard permission (see §9) |

### About

App icon, name, version and build, "Free and open-source under GPL-3.0", links: Source Code, Report an Issue, Acknowledgements (third-party licenses, shown in a sheet from `App/Credits.rtf`). An Updates section with an "Automatically check for updates" toggle (off by default) and a Check for Updates… button.

Decided (T13.1, WD-19): update settings live in About.
There is no Advanced pane; capture polling and the size limit are fixed ([WD-1](roadmap.md#working-defaults-for-open-todos), [product §4.1](product.md#41-capture)).

---

## 9. Onboarding and permissions

A single window shown on first launch (SwiftUI, standard window chrome, glass toolbar). Three short steps, all skippable. Text below is our own and still a draft.

| Step | Content | Controls |
|---|---|---|
| 1. Welcome | App icon; one line: "Everything you copy, one shortcut away." Shows the current Open Shelf shortcut with a recorder to change it. | Continue |
| 2. Paste directly | Explains that pasting into other apps needs Accessibility permission, and that without it Clipsy copies the item and the user presses ⌘V. Live status row that turns green when granted (polled while the step is visible). | Open System Settings…, Not Now |
| 3. Clipboard access | On systems where macOS asks before an app reads the clipboard, explains why Clipsy needs ongoing access and how to allow it. Live status row. Skipped when the system does not gate access. | Open System Settings…, Not Now |
| Finish | Two toggles: Open at login, Keep history for (pop-up). Hint: press the shortcut to try it. | Done |

Rules:
- Never block the app on a missing permission. The Shelf works in copy-only mode without Accessibility.
- When a paste fails for lack of permission, show one standard alert offering "Open System Settings…" and "Copy Only", with a "Don't ask again" checkbox (suppression button).
- Permission status is re-checked when the app becomes active; Settings rows update live.
- No seeded Boards or sample Cards.

Step 3 and the Privacy pane row read `NSPasteboard.general.accessBehavior` (checked against the macOS 26 SDK). The step and the row appear only once macOS has asked about Clipsy (`.ask`, `.alwaysAllow` or `.alwaysDeny`); `.default` means the system never asked, so there is nothing to set. The pane is System Settings › Privacy & Security › Paste from Other Apps, and its button opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard` (the anchor is in the macOS 27.2 System Settings; the copy names the pane in case the anchor does not resolve). The Accessibility button calls the system prompt instead of a URL (WD-27).

> TODO: whether reading `changeCount` alone triggers the pasteboard prompt on macOS 26 (see [product.md §4.1](product.md#41-capture)).
> TODO: verify on macOS 26 that the `Privacy_Pasteboard` anchor opens the Paste from Other Apps list.

---

## 10. Accessibility and appearance

| Area | Requirement |
|---|---|
| VoiceOver: Card | Label "*Type* from *App*, *relative time*", e.g. "Image from Preview, 2 minutes ago"; value = first line of text, link title, file name or color value; custom actions for Paste, Paste as Plain Text, Copy, Quick Look, Add to Board, Delete. |
| VoiceOver: Shelf | The Card strip is a list with item count; Board switcher is a tab group; quick-paste badges are exposed as part of the Card label ("number 3") only while visible. |
| Announcements | Announce capture paused/resumed, item deleted (with undo hint), Sequence item pasted. |
| Keyboard only | Every action has a key or is in a menu reachable from the keyboard; Tab moves between search field, Board switcher and Card strip; focus ring always visible. Key map in [product.md](product.md). |
| Reduce Motion | Crossfades replace springs, morphs and slides (see §2 Motion). |
| Reduce Transparency | Glass falls back to the system opaque material automatically; we add no custom blur that would ignore the setting. |
| Increase Contrast | Card borders become stronger (system behavior of `separatorColor`); selection ring thickens (proposed +1 pt); Board dots gain an outline. |
| Liquid Glass appearance | Test with the system Clear and Tinted glass options. |
| Color independence | Board identity never relies on color alone: the name is always shown next to the dot. Selection uses a ring, not only a fill. |
| Text size | System text styles only, so the macOS text size setting (where honored) applies. |
| Light / Dark | Semantic colors only; no hard-coded colors anywhere. Image and color Cards show content as-is in both modes. |

---

## 11. Component mapping

| Element | Component |
|---|---|
| Shelf window | `NSPanel` subclass, non-activating, full-size content view, resizable from the top edge, floating level, joins the active Space and full-screen Spaces; `sharingType = .none` unless the privacy toggle is on. Details in [architecture.md](architecture.md). |
| Shelf background | SwiftUI `.glassEffect(.regular, in: .rect(cornerRadius:))` on a background layer of the root view (see [§2 Metrics](#metrics)), concentric corner radius |
| Shelf content | SwiftUI hosted in `NSHostingView` |
| Card strip | Horizontal `ScrollView` + `LazyHStack` (or `NSCollectionView` if performance needs it) |
| Card | SwiftUI view with opaque `background(.background.secondary)` fill and `separatorColor` stroke; no glass |
| Selection ring | Custom stroke in `Color.accentColor`, `.focusEffectDisabled()` on the Card |
| Quick-paste badge | `Text` with `.glassEffect(in: .capsule)` |
| Top bar | `GlassEffectContainer` with `.glassEffectID` per capsule for morphing |
| Search field | SwiftUI search field with tokens (`.searchable(text:tokens:)` style API) or `NSSearchField` with token attachments if the SwiftUI variant does not work inside the panel |
| Filters | Button with `.buttonStyle(.glass)` opening a `.popover` |
| Board capsules | `Button` with `.buttonStyle(.glass)`; selected uses `.glassProminent` |
| Board color dot | `Circle().fill(Color(nsColor: .systemBlue))` etc. |
| Empty states | `ContentUnavailableView` |
| Context menu | `NSMenu` / SwiftUI `.contextMenu` with `Label` items (SF Symbols), `Divider` between sections, destructive role on Delete |
| Quick Look | `NSPopover` containing `QLPreviewView` (files) or SwiftUI previews (images, text, links, colors) |
| Edit sheet | `.sheet` with `Form`, `ColorPicker`, standard toolbar; the text editor is an `NSTextView` in `NSViewRepresentable`, because RTF in and out needs AppKit font attributes that SwiftUI's `TextEditor` does not keep |
| New/Edit Board | Sheet with `TextField` and a swatch row |
| Sequence panel | Separate `NSPanel` (utility, non-activating) hosting SwiftUI; header in `GlassEffectContainer`; rows in `List` with `.onMove` and `.onDelete` |
| Menu bar extra | `NSStatusItem` with an `NSMenu` ([WD-35](roadmap.md#working-defaults-for-open-todos)) |
| Symbol effects | `.symbolEffect(.bounce)` on capture |
| Settings | `Settings` scene, `TabView` with `.tabItem`, `Form` + `.formStyle(.grouped)` |
| Shortcut recorder | `KeyboardShortcuts.Recorder` from KeyboardShortcuts ([architecture §2](architecture.md#2-stack)) |
| Ignored apps list | `List` + `NSOpenPanel` limited to applications |
| Onboarding | SwiftUI `Window` scene with a step container and standard buttons |
| Alerts | `.alert` / `NSAlert` with `showsSuppressionButton` |
| Toast/HUD | None. The menu bar symbol shows the paused state ([§7](#7-menu-bar-extra)) and sounds confirm capture and paste ([WD-34](roadmap.md#working-defaults-for-open-todos)) |

Checked against the macOS 26 SDK: SwiftUI has `.glass`, `.glassProminent`, `glassEffectID(_:in:)` and `glassEffectUnion(id:namespace:)`; `NSGlassEffectView` has `contentView`, `cornerRadius`, `tintColor` and `style`.

---

## 12. Open questions

These still need a test on real hardware or the task that settles them. Choices that follow a working default are in [roadmap.md](roadmap.md#working-defaults-for-open-todos); features left for later are in [roadmap.md](roadmap.md#later-not-scheduled).

> TODO: Quick Look as popover vs system `QLPreviewPanel` (§5).
> TODO: whether reading `changeCount` alone triggers the pasteboard prompt on macOS 26, and whether the `Privacy_Pasteboard` anchor opens the Paste from Other Apps list (§9).
> TODO: compact-mode threshold and Card sizes: tune on 13" and 27"+ displays ([WD-15](roadmap.md#working-defaults-for-open-todos) until then).
> TODO: maximum Board count in the switcher before it scrolls or collapses into a menu.
> TODO: behavior and visuals on macOS releases after 26 (Liquid Glass changes not yet reviewed).
