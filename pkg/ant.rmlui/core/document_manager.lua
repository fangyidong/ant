local rmlui = require "rmlui"
local event = require "core.event"
local environment = require "core.environment"
local createSandbox = require "core.sandbox.create"
local filemanager = require "core.filemanager"
local constructor = require "core.DOM.constructor"
local eventListener = require "core.event.listener"
local console = require "core.sandbox.console"
local datamodel = require "core.datamodel.api"
local task = require "core.task"

local elementFromPoint = rmlui.DocumentElementFromPoint
local getBody = rmlui.DocumentGetBody
local getParent = rmlui.NodeGetParent
local setPseudoClass = rmlui.ElementSetPseudoClass

local m = {}

local width, height = 1, 1
local screen_ratio = 1.0
local documents = {}
local hidden = {}
local pending = {}
local update

local function round(x)
    return math.floor(x*screen_ratio+0.5)
end

local function notifyDocumentCreate(document, path, name)
	local globals = createSandbox(path)
	event("OnDocumentCreate", document, globals)
	globals.window.document = globals.document
	globals._extern_name = name
	environment[document] = globals
end

local function notifyDocumentDestroy(document)
	event("OnDocumentDestroy", document)
	environment[document] = nil
end

local function OnLoadInlineScript(document, source_path, content, source_line)
	local f, err = filemanager.loadstring(content, source_path, source_line, environment[document])
	if not f then
		console.warn(err)
		return
	end
	f()
end

local function OnLoadExternalScript(document, source_path)
	local f, err = filemanager.loadfile(source_path, environment[document])
	if not f then
		console.warn(("file '%s' load failed: %s."):format(source_path, err))
		return
	end
	f()
end

local function OnLoadInlineStyle(document, source_path, content, source_line)
    rmlui.DocumentLoadStyleSheet(document, source_path, content, source_line)
end

local function OnLoadExternalStyle(document, source_path)
    if not rmlui.DocumentLoadStyleSheet(document, source_path) then
        rmlui.DocumentLoadStyleSheet(document, source_path, filemanager.readfile(source_path))
    end
end

function m.open(path, name)
    local doc = rmlui.DocumentCreate(width, height)
    if not doc then
        return
    end
    documents[#documents+1] = doc
    notifyDocumentCreate(doc, path, name)
    local html = rmlui.DocumentParseHtml(path, filemanager.readfile(path), false)
    if not html then
        m.close(doc)
        return
    end
    local scripts = rmlui.DocumentInstanceHead(doc, html)
    for _, load in ipairs(scripts) do
        local type, str, line = load[1], load[2], load[3]
        if type == "script" then
            if line then
                OnLoadInlineScript(doc, path, str, line)
            else
                OnLoadExternalScript(doc, str)
            end
        elseif type == "style" then
            if line then
                OnLoadInlineStyle(doc, path, str, line)
            else
                OnLoadExternalStyle(doc, str)
            end
        end
    end
    rmlui.DocumentInstanceBody(doc, html)
    datamodel.update(doc)
    rmlui.DocumentFlush(doc)
    return doc
end

function m.onload(doc)
    --TODO
    eventListener.dispatch(doc, getBody(doc), "load", {})
end

function m.show(doc)
    hidden[doc] = nil
end

function m.hide(doc)
    hidden[doc] = true
end

function m.flush(doc)
    datamodel.update(doc)
    rmlui.DocumentFlush(doc)
end

function m.close(doc)
    if update then
        task.new(function ()
            m.close(doc)
        end)
        return
    end
    eventListener.dispatch(doc, getBody(doc), "unload", {})
    notifyDocumentDestroy(doc)
    rmlui.DocumentDestroy(doc)
    for i, d in ipairs(documents) do
        if d == doc then
            table.remove(documents, i)
            break
        end
    end
    hidden[doc] = nil
end

local function fromPoint(x, y)
    for i = #documents, 1, -1 do
        local doc = documents[i]
        if not hidden[doc] then
            local e = elementFromPoint(doc, x, y)
            if e then
                return doc, e
            end
        end
    end
end

local gesture = {}

function gesture.tap(doc, e, ev)
    eventListener.dispatch(doc, e, "click", ev)
end

function gesture.longpress(doc, e, ev)
    eventListener.dispatch(doc, e, "longpress", ev)
end

function gesture.pan(doc, e, ev)
    ev.velocity_x = round(ev.velocity_x)
    ev.velocity_y = round(ev.velocity_y)
    eventListener.dispatch(doc, e, "pan", ev)
end

function gesture.pinch(doc, e, ev)
    ev.velocity = round(ev.velocity)
    eventListener.dispatch(doc, e, "pinch", ev)
end

function gesture.swipe(doc, e, ev)
    eventListener.dispatch(doc, e, "swipe", ev)
end

function m.process_gesture(ev)
    local f =  gesture[ev.what]
    if not f then
        return
    end
    local x, y = round(ev.x), round(ev.y)
    local doc, e = fromPoint(x, y)
    if e then
        ev.x = x
        ev.y = y
        f(doc, e, ev)
        return true
    end
end

local function walkElement(doc, e)
    local r = {}
    while true do
        local element = constructor.Element(doc, false, e)
        r[#r+1] = element
        r[element] = true
        e = getParent(e)
        if not e then
            break
        end
    end
    return r
end

local activeElement = {}

local function cancelActive(id)
    local actives = activeElement[id]
    if not actives then
        return
    end
    for _, e in ipairs(actives) do
        if e._handle then
            setPseudoClass(e._handle, "active", false)
        end
    end
    activeElement[id] = nil
    return true
end

local function setActive(doc, e, id)
    cancelActive(id)
    local actives = walkElement(doc, e)
    activeElement[id] = actives
    for _, e in ipairs(actives) do
        setPseudoClass(e._handle, "active", true)
    end
end

function m.process_touch(ev)
    if ev.state == "began" then
        local x, y = round(ev.x), round(ev.y)
        local doc, e = fromPoint(x, y)
        if e then
            setActive(doc, e, ev.id)
            return true
        end
    elseif ev.state == "ended" or ev.state == "cancelled" then
        if cancelActive(ev.id) then
            return true
        end
    elseif ev.state == "moved" then
        if activeElement[ev.id] then
            return true
        end
    end
end

function m.set_dimensions(w, h, ratio)
    screen_ratio = ratio
    if w == width and h == height then
        return
    end
    width, height = w, h
    for _, doc in ipairs(documents) do
        rmlui.DocumentSetDimensions(doc, width, height)
        eventListener.dispatch(doc, getBody(doc), "resize", {})
    end
end

function m.updatePendingTexture(doc, v)
    if not doc then
        return
    end
    if pending[doc] then
        local newv = pending[doc] + v
        if newv == 0 then
            pending[doc] = nil
        else
            pending[doc] = newv
        end
    else
        pending[doc] = v
    end
end

function m.getPendingTexture(doc)
    return pending[doc] or 0
end

local function updateTexture()
    local q = filemanager.updateTexture()
    if not q then
        return
    end
    for i = 1, #q do
        local v = q[i]
        if v.id then
            rmlui.RenderSetTexture(v.path, v.id, v.width, v.height)
            for _, e in ipairs(v.elements) do
                if e._handle then
                    rmlui.ElementDirtyImage(e._handle)
                end
                m.updatePendingTexture(e._document, -1)
            end
        else
            rmlui.RenderSetTexture(v.path)
        end
    end
end

function m.update(delta)
    updateTexture()
    update = true
    rmlui.RenderBegin()
    for _, doc in ipairs(documents) do
        if not hidden[doc] then
            datamodel.update(doc)
            rmlui.DocumentUpdate(doc, delta)
        end
    end
    rmlui.RenderFrame()
    update = nil
end

return m
