local rmlui = require "rmlui"

local timer = require "core.timer"
local task = require "core.task"
local filemanager = require "core.filemanager"
local windowManager = require "core.windowManager"
local contextManager = require "core.contextManager"
local initRender = require "core.initRender"
local ltask = require "ltask"
local bgfx = require "bgfx"
local ServiceWindow = ltask.queryservice "ant.window|window"

require "core.DOM.constructor":init()

local quit

local _, last = ltask.now()
local function getDelta()
    local _, now = ltask.now()
    local delta = now - last
    last = now
    return delta * 10
end

local function Render()
    bgfx.encoder_create "rmlui"
    while not quit do
        local delta = getDelta()
        if delta > 0 then
            timer.update(delta)
        end
        contextManager.update(delta)
        task.update()
        bgfx.encoder_frame()
    end
    bgfx.encoder_destroy()
    ltask.wakeup(quit)
end

local S = {}

function S.initialize(t)
    bgfx.init()
    ServiceWorld = t.service_world
    require "font" (t.font_mgr)
    initRender(t)
    ltask.fork(Render)
end

function S.shutdown()
    quit = {}
    ltask.wait(quit)
	ltask.send(ServiceWindow, "unsubscribe_all")
    rmlui.RmlShutdown()
    bgfx.shutdown()
end

S.open = windowManager.open
S.close = windowManager.close
S.postMessage = windowManager.postMessage
S.add_bundle = filemanager.add_bundle
S.del_bundle = filemanager.del_bundle
S.set_prefix = filemanager.set_prefix
S.mouse = contextManager.process_mouse
S.touch = contextManager.process_touch
S.gesture = contextManager.process_gesture
S.update_context_size = contextManager.set_dimensions

ltask.send(ServiceWindow, "priority", 1)

ltask.send(ServiceWindow, "subscribe", {
    "mouse",
    "touch",
    "gesture",
})

return S
