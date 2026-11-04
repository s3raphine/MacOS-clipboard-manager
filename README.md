A redesigned panel, a working global shortcut and a new app icon.

## New
- New interface with Pinned and Recent sections, in light and dark mode
- App icon
- Full keyboard control: ↑ ↓ to navigate, ↩ to copy, ⌘P to pin, ⌘⌫ to delete
- Copied files are now kept in the history
- Your current app stays in front, so you can paste right after picking an item
- Quit button, and a confirmation before clearing the history

## Fixed
- ⌘⇧V now opens the panel from anywhere
- Passwords flagged as concealed by password managers are no longer recorded
- Words like "add" or "facade" are no longer detected as colors
- Sentences starting with a link are no longer detected as links
- Text copied from Office apps and files copied from Finder are no longer saved as images
- PNG-only images are now captured
- Copying something already in the history moves it to the top instead of duplicating it
- Smoother scrolling and saving with large items
- The history file is readable only by your user account

## Install
Unzip, move the app to /Applications and open it. The app isn't notarized, so macOS blocks it the first time: go to System Settings > Privacy & Security and click Open Anyway.

Requires macOS 13 or later. This build is for Apple silicon. On an Intel Mac, build from source with `./build.sh`.
