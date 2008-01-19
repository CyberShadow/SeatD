=====================================================================
SEATD for Kate
=====================================================================

- When SEATD for Kate is properly installed, it will show up in Kate's Plugin list in Setting > Configure Kate > Application > Plugins
- Check the box to enable it. If the plugin is built properly, a sidebar button should appear. Else it will be unchecked in the plugin list when you reopen the config dialog.

- You can configure 2 shortcuts, that will activate and refresh the declaration- and modules-list, respectively.
- Using these shortcuts will re-parse the current file, update the list and focus the search input field.
- Typing in the seach field will shrink the list, such that only items that contain the search term are displayed.
- Use the up/down arrow keys to navigate the list.
- Enter or Space jump to the selected item, just like single- or double clicking it (depending on you KDE settings)
- Pressing a shortcut or Escape, while the search input field is focused will set the focus back to the editor

- Only files that are open in the editor will be re-parsed and not until the editor view is swtiched to that file.
- Imports will be parsed only once, the first time they appear as a dependency to a file that is opened in the editor.
