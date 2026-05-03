# Search Results Refactor — Design

**Date:** 2026-05-03  
**Status:** Approved  
**Scope:** `lib/features/matching/presentation/screens/search_announcement_screen.dart`

---

## Goal

Refactor the search results page to:
1. Move the list/map toggle from the AppBar header to the leftmost position in the filter chips row
2. Always display toggle icons first (no horizontal scroll needed to see them)
3. Default to list view on search results load
4. Remove the `DonyBottomNav` (bottom navigation bar) completely on this page

---

## Non-Goals

- Change filter logic or behavior
- Change the styling of filter chips themselves
- Modify announcement card layout or map view rendering
- Add new filters or search parameters

---

## Design

### 1. AppBar Changes

**Current:** Toggle (Liste/Carte tabs) in AppBar + filter icon  
**New:** Filter icon only, more space for the journey title

```
┌─────────────────────────────────────────┐
│ Paris → Dakar                    [🔧]   │  AppBar
└─────────────────────────────────────────┘
```

The AppBar now displays:
- Journey title (departure → arrival city)
- Filter icon (🔧) with red dot when filters are active
- No toggle tabs

---

### 2. Filter Chips Row Restructure

**Current structure:**
```
[★ 4.7+] [€/kg ↓] [Cette semaine] [+10 kg]
```

**New structure:**
```
[📋 Liste] [🗺️ Carte] [★ 4.7+] [€/kg ↓] [Cette semaine] [+10 kg]
↑ ALWAYS VISIBLE — first item, no scroll needed
```

The toggle icons are the **first items** in the horizontal ListView. When the user scrolls right, they scroll past the toggle but it remains pinned to the left edge.

---

### 3. Toggle Icons Styling

**Visual specs (per design system):**

- **Size:** 24×24 pt icons
- **Container:** Pill-shaped (border-radius 12pt), height 40pt
- **Spacing between icons:** 4pt
- **Padding around each icon:** 8pt horizontal, 8pt vertical

**Active state (currently selected view):**
- Background: light primary tint (`DonyColors.primary` with opacity 0.1)
- Icon color: `DonyColors.primary` (#0B5FFF)
- Font weight: w600 if text label included, otherwise icon only

**Inactive state (not selected):**
- Background: transparent
- Icon color: `DonyColors.neutral500` (gray)

**Icons:**
- List view: `Icons.list_rounded` (or `Icons.view_list_rounded`)
- Map view: `Icons.map_outlined`

**Animation on toggle:**
- Tap active icon: no change
- Tap inactive icon: fade transition 200ms (`Curves.easeOutCubic`)
- IndexedStack switches children during transition

---

### 4. Navigation Bar Behavior

**Current:** `DonyBottomNav` visible on search results page (part of GoRouter shell)  
**New:** `DonyBottomNav` is **completely hidden** (not visible at all)

**Implementation approach:**
- Create a new GoRoute `/search-results` that does **not** use the main shell (`DonyBottomNav`)
- This route is still child of `SearchAnnouncementScreen`, but renders fullscreen without bottom nav
- User navigates back to home via back button (standard Android/iOS behavior) or tapping home after returning to the filter form

---

### 5. View State & Lifecycle

**Initial state:**
- `_isMapView = false` (default list view)
- List icons is active (colored), map icon is inactive (gray)

**On search button click:**
- Load results → display list view
- `_isMapView` is reset to `false`
- All IndexedStack children (list + map) are mounted but only list is visible

**On toggle interaction:**
- User taps list icon: `setState(() => _isMapView = false)` → IndexedStack shows list
- User taps map icon: `setState(() => _isMapView = true)` → IndexedStack shows map

**Persistence:**
- If user navigates away and back to results, `_isMapView` state is lost (resets to list)
- This is acceptable — each search session starts with list view

---

### 6. Files Changed

| File | Action |
|---|---|
| `lib/features/matching/presentation/screens/search_announcement_screen.dart` | Remove _ToggleTab from AppBar; move toggle logic to filter chips row as icon buttons |
| `lib/app/router.dart` | Ensure search results route does not use shell with `DonyBottomNav` |
| `lib/core/design/widgets/` | (Optional) Extract toggle logic into a reusable `ListMapToggle` widget if it gets complex |

---

### 7. UX Flow

**Step 1:** User enters search form (form screen with filters + departure/arrival)  
→ `DonyBottomNav` is visible (normal home navigation)

**Step 2:** User taps Search button  
→ Navigate to `/search-results` route (no shell)  
→ Fullscreen results page loads  
→ `DonyBottomNav` disappears  
→ List view displays (default)

**Step 3a (List → Map):** User taps map icon  
→ Map view appears  
→ Map icon becomes active (colored)

**Step 3b (Map → List):** User taps list icon  
→ List view appears  
→ List icon becomes active (colored)

**Step 4:** User taps back button (iOS: swipe back, Android: device back)  
→ Return to filter form  
→ `DonyBottomNav` reappears

---

### 8. Behavior Notes

- **Horizontal scroll on chips row:** The list/map toggle is the first item (pinned-left semantic), but it scrolls with the chips row if user scrolls right to see more filters. This is acceptable — the toggle is still functional even if scrolled out of view.
- **Touch target:** Each icon is 24pt, but wrapped in a 40pt-tall button container → sufficient touch area (≥ 44pt vertical)
- **Multiple taps:** If user rapidly taps list/map icons, the state updates via `setState`. No debouncing needed — Flutter rebuilds are fast enough.

---

### 9. Design System Compliance

✅ **Colors:** `DonyColors.primary` (#0B5FFF), `DonyColors.neutral500` (gray)  
✅ **Typography:** Icons only, no text labels (saves space)  
✅ **Spacing:** 8pt padding (aligns with `DonySpacing` tokens)  
✅ **Border radius:** 12pt (consistent with chip styling)  
✅ **Animations:** 200ms fade (within 500ms budget)  
✅ **Touch targets:** ≥ 44pt height (vertical safety)  

---

## Out of Scope

- Filter by transport mode (can be added later)
- Animate marker appearance on map
- Persist view preference across sessions (list is always default)
- Custom toggle widget — use simple `IconButton` + `setState`

