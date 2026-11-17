---
name: macos-native-ui
description: How to build Clipsy UI that looks and behaves like a first-party macOS 26/27 component, and how to verify it. Covers Liquid Glass, materials, the shelf panel, windows, menus, the Settings scene, the menu bar extra, SF Symbols, keyboard and accessibility. Use before writing or changing any SwiftUI or AppKit UI.
---

# Native macOS UI for Clipsy

The goal is for a user to believe Apple shipped the shelf. When unsure, copy what a system app does (Spotlight, Finder, Mail, System Settings) instead of inventing something.

The binding rules are R5 in `.claude/rules/code-rules.md`, and reviews cite those. This skill is the how-to behind them, plus the verification routine.

## Read first

1. [docs/design.md](../../../docs/design.md) is the source of truth for every Clipsy screen. If what you are about to build contradicts it, stop and ask.
2. Apple's agent guides, bundled with Xcode on the developer's machine. Read the one that matches the API you are about to use:
   - `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/SwiftUI-Implementing-Liquid-Glass-Design.md`
   - `.../AdditionalDocumentation/AppKit-Implementing-Liquid-Glass-Design.md`
   - `.../AdditionalDocumentation/SwiftUI-New-Toolbar-Features.md`
   - `.../AdditionalDocumentation/Swift-Concurrency-Updates.md`
3. Vendored references in `../swiftui-expert-skill/references/`: `macos-scenes.md`, `macos-views.md`, `macos-window-styling.md`, `liquid-glass.md`, `toolbar-patterns.md`, `accessibility-patterns.md`.
4. HIG: <https://developer.apple.com/design/human-interface-guidelines/materials> and <https://developer.apple.com/design/human-interface-guidelines/>.

Before using any glass, toolbar or window API newer than your training data, confirm it exists. Use the Xcode MCP `DocumentationSearch` tool or the files above. Never invent API names.

## Liquid Glass

- Glass is the functional layer: toolbars, sidebars, the shelf container, the search and filter bar, floating controls. Content is never glass. Cards, previews and text use standard materials or opaque system backgrounds.
- System components pick up glass on their own. Before adding a custom `glassEffect`, remove any custom background behind toolbars, sidebars and sheets. Custom backgrounds break glass and the scroll-edge effect.
- For a custom glass control:
  - Wrap groups in `GlassEffectContainer` (in AppKit, `NSGlassEffectContainerView`).
  - Apply `.glassEffect` after the layout and visual modifiers.
  - Add `.interactive()` only to controls the user can act on.
  - Use `glassEffectID` with a `@Namespace` for morphing transitions.
- Use the `.regular` variant by default. Use `.clear` only over rich media.
- Use tint only to carry meaning, such as state or a primary action, never for decoration. Prefer `.buttonStyle(.glass)` and `.glassProminent` over hand-rolled glass buttons.
- Use glass sparingly, because every effect costs GPU time. One container is better than many separate effects.
- In AppKit, only the `contentView` of an `NSGlassEffectView` is guaranteed to be inside the glass. Do not add arbitrary subviews.

## Color, type, symbols, spacing

- Use semantic colors and hierarchical styles only: `.primary`, `.secondary`, `.tertiary`, `.tint`, `Color(nsColor: .controlAccentColor)`. No hex colors in views. Board colors map to named system colors.
- Use system text styles (`.body`, `.callout`, `.caption`, `.headline`) and never fixed point sizes. Use monospaced digits for counters (`.monospacedDigit()`).
- Use SF Symbols for every icon, with the rendering mode the system uses for that context. No custom icon artwork except the app icon.
- Take corner radii, paddings and sizes from the design-constants type in `DesignSystem`. Do not scatter magic numbers. Prefer the system's concentric shapes and `containerRelativeFrame` to computing geometry by hand.
- Do not paint sidebars or root panes with opaque colors such as `windowBackgroundColor`.

## Windows and the shelf panel

- The shelf is a non-activating `NSPanel` hosting SwiftUI through `NSHostingView`. It never steals focus from the app the user will paste into.
- Collection behavior: it appears on the active Space, over full-screen apps, and stays out of Mission Control. Set the level the way docs/design.md specifies.
- Position the panel on the screen under the pointer or the key window's screen, never `NSScreen.main`. AppKit's y-axis starts at the bottom; Quartz's starts at the top. Convert explicitly.
- Opening and closing use the standard animation durations. With Reduce Motion on, use a fade instead of a slide.
- The panel closes on Escape, on loss of key status, and when the user activates another app. These rules live in docs/product.md; follow them exactly.

## Scenes, menus, settings

- Use the `Settings` scene with a `TabView` of `Form`s and `.formStyle(.grouped)`, the way System Settings panes look. Open it with `SettingsLink` or `openSettings`. Never build a custom preferences window.
- Use `MenuBarExtra` for the menu bar item unless docs/design.md requires `NSStatusItem` behaviour that SwiftUI lacks. Decide deliberately between the `.accessory` and `.regular` activation policy.
- Every repeatable action is a command (`CommandMenu`, `CommandGroup`) with a keyboard shortcut. Context menus mirror the commands, in the same order and with the same names.
- Use `ContentUnavailableView` for empty states, `LabeledContent` in forms, and `Label` everywhere an icon sits next to text.
- Name things the macOS way: "Settings…" (not "Preferences"), title-case menu items, and an ellipsis on items that open further UI.

## Keyboard and accessibility

- Everything works from the keyboard: arrows to move the selection, Return to perform the default action, Escape to cancel, ⌘F for search, the number shortcuts for quick paste. Show focus rings where the system shows them.
- Icon-only controls carry text, as in `Button("Add to Board", systemImage: "pin")`, so VoiceOver and tooltips work. Cards expose a combined label and custom actions such as paste, add to board and delete.
- Honor Reduce Motion, Reduce Transparency, Increase Contrast and Differentiate Without Color. Text keeps at least 4.5:1 contrast on every material.

## Verify before you say it is done

1. Build and run the app. Look at the screen you changed.
2. Check it in light and dark mode. Then turn on Reduce Transparency and Increase Contrast and check again.
3. Test it on a second display and over a full-screen app if the change involves the panel.
4. Drive the whole flow with the keyboard only.
5. Compare it side by side with the closest system UI. If it looks custom, it is wrong.
