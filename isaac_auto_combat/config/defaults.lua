-- Default configuration values for the auto combat mod.
local toggleKey = nil
if Keyboard ~= nil then
  toggleKey = Keyboard.KEY_G
end

return {
  toggleAction = nil,
  toggleKey = toggleKey,
  overlay = {
    enabled = true,
    page = 1,
  },
}
