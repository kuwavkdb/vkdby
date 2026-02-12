# Issue #205 Reproduction Plan

## Objective
Confirm that the global navigation menu is hidden on mobile devices and that there is no alternative menu accessible.

## Steps
1. Open the application in a mobile viewport (e.g., width < 640px).
2. Observe the header area.
3. Verify that the "Units", "People", "Trends", "Items" links are not visible.
4. Verify that there is no "hamburger" icon or other menu trigger to reveal these links.

## Expected Behavior (Current)
- Navigation links are hidden.
- No way to access navigation on mobile.

## Goal
- Implement a mobile menu trigger (hamburger icon).
- Implement a mobile menu (dropdown or slide-out) containing the navigation links.
