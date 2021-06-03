API = require("ButtonAPI")
local filesystem = require("filesystem")
local component = require("component")
local keyboard = require("keyboard")
local event = require("event")
local gpu = component.gpu


local colors = { blue = 0x4286F4, purple = 0xB673d6, red = 0xC14141, green = 0xDA841,
  black = 0x000000, white = 0xFFFFFF, grey = 0x47494C, lightGrey = 0xBBBBBB}
-- set size of the screen for lvl 3
gpu.setResolution(132,38)
gpu.setBackground(colors.black)
gpu.fill(1, 1, 132, 38, " ")


function setButtons()
  API.setTable("ON", powerOn, 91, 5, 106, 7,"ON", {on = colors.green, off = colors.green})
  API.setTable("OFF", powerOff, 109, 5, 125, 7,"OFF", {on = colors.red, off = colors.red})

  API.setTable("lowerMinLimit", lowerMinLimit, 91, 15, 106, 17,"-10", {on = colors.blue, off = colors.blue})
  API.setTable("lowerMaxLimit", lowerMaxLimit, 109, 15, 125, 17,"-10", {on = colors.purple, off = colors.purple})

  API.setTable("augmentMinLimit", augmentMinLimit, 91, 19, 106, 21,"+10", {on = colors.blue, off = colors.blue})
  API.setTable("augmentMaxLimit", augmentMaxLimit, 109, 19, 125, 21,"+10", {on = colors.purple, off = colors.purple})
end

function startup()
  setButtons()
end


startup()
API.screen()

event.listen("touch", API.checkxy)


while event.pull(0.1, "interrupted") == nil do
  local event, address, arg1, arg2, arg3 = event.pull(1)
  if type(address) == "string" and component.isPrimary(address) then
    if event == "key_down" and arg2 == keyboard.keys.q then
      os.exit()
    end
  end
end