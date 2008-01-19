=====================================================================
SEATD for Kate
=====================================================================

- When SEATD for Kate is properly installed, it will show up in Kate's Plugin list in Setting > Configure Kate > Application > Plugins
- Check the box to enable it. If the plugin is built properly, a sidebar button should appear. Else it will be unchecked in the plugin list when you reopen the config dialog.

- You can configure 3 shortcuts:
    - activate and refresh the declaration list
    - activate and refresh the module list
    - goto declaration of symbol at cursor
- Refreshing a list will re-parse the current file, update the list and focus the search input field.
- Typing in the seach field will shrink the list, such that only items that contain the search term are displayed.
- Use the up/down arrow keys to navigate the list.
- Enter or Space jump to the selected item, just like single- or double clicking it (depending on you KDE settings)
- Pressing a list-shortcut or Escape, while the search input field is focused will set the focus back to the editor

- Only files that are open in the editor will be re-parsed and not until the editor view is swtiched to that file.
- Imports will be parsed only once, the first time they appear as a dependency to a file that is opened in the editor.

- SEATD will try to infer the include paths from the parsed file's path and the D module names.
- It will still need explicitly set include paths to find for example Tango or any imports that do not reside in the parsed file's hierarchy.
- You can use Kate modlines to add additional include paths. The value to set is call SEATDIncludePath. For example, you can add the following line to a D source file, to allow parsing of Phobos, Tango and such:
// Kate: SEATDIncludePath /usr/include/d/4.1
- SEATD is greedy when it comes to include paths. It'll use any include path set in any file that is open in the editor to parse imports of any other open file.
