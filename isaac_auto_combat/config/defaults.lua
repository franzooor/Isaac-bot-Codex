return {
  -- Default toggle uses the ö key (shares the semicolon scancode on QWERTZ
  -- layouts). Players can change this to another keyboard key or bind a
  -- specific ButtonAction via config/user_prefs.lua.
  toggleAction = nil,
  toggleKeyboardKey = Keyboard and Keyboard.KEY_SEMICOLON or nil,
  overlay = {
    enabled = true,
    page = 1,
  },
}
