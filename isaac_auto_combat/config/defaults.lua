-- Default configuration values for the auto combat mod.
return {
  -- Default toggle is bound to Menu Confirm (Enter on keyboard) which is unused in
  -- normal gameplay. Players can remap this to any other action via
  -- config/user_prefs.lua.
  toggleAction = ButtonAction.ACTION_MENUCONFIRM,
  overlay = {
    enabled = true,
    page = 1,
  },
}
