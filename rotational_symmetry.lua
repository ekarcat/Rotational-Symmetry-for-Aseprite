-- Rotational Symmetry Script For Aseprite 20261019 (Google Gemini)
----------------------------------------------------------------------

if app.apiVersion < 1 then
    return app.alert("This script requires Aseprite v1.2.10+")
end

----------------------------------------------------------------------
-- State Variables
----------------------------------------------------------------------
local isRunning = false
local isApplying = false
local clockwise = false
local symmetryOrder = 4

local w, h, cx, cy = 0, 0, 0, 0
local activeSprite = nil
local rotations = {}
local inverseRotations = {} 
local siteListenerCode = nil
local lastCanvas = nil 

----------------------------------------------------------------------
-- Geometry & Rotational Math
----------------------------------------------------------------------
local function computeRotations()
    rotations = {}
    inverseRotations = {}
    local dir = clockwise and -1 or 1
    for i = 1, symmetryOrder - 1 do
        local angle = dir * i * (2 * math.pi / symmetryOrder)
        rotations[i] = {
            cos = math.cos(angle),
            sin = math.sin(angle)
        }
        inverseRotations[i] = {
            cos = math.cos(-angle),
            sin = math.sin(-angle)
        }
    end
end

-- [BUG FIX] Rounding function to compensate for floating-point errors
local function safeRound(val)
    if val >= 0 then
        return math.floor(val + 0.50001)
    else
        return math.ceil(val - 0.50001)
    end
end

local function rotatePoint(px, py, rotIndex)
    local r = rotations[rotIndex]
    local rx = (px + 0.5) - cx
    local ry = (py + 0.5) - cy
    local newRx = rx * r.cos - ry * r.sin
    local newRy = rx * r.sin + ry * r.cos
-- Applied correction to prevent micro floating-point errors from bouncing pixels at the 0.5 threshold.
    return safeRound(newRx + cx - 0.5), safeRound(newRy + cy - 0.5)
end

local function rotatePointInverse(px, py, rotIndex)
    local r = inverseRotations[rotIndex]
    local rx = (px + 0.5) - cx
    local ry = (py + 0.5) - cy
    local newRx = rx * r.cos - ry * r.sin
    local newRy = rx * r.sin + ry * r.cos
-- Applied correction to prevent micro floating-point errors from bouncing pixels at the 0.5 threshold.
    return safeRound(newRx + cx - 0.5), safeRound(newRy + cy - 0.5)
end

local function inBounds(px, py)
    return px >= 0 and px < w and py >= 0 and py < h
end

local function syncLastCanvas()
    if not app.sprite then return end
    lastCanvas = Image(w, h, app.sprite.colorMode)
    if app.activeLayer and app.activeFrame then
        local cel = app.activeLayer:cel(app.activeFrame)
        if cel and cel.image then
            for it in cel.image:pixels() do
                local px = it()
                if px ~= 0 then
                    local tx = it.x + cel.position.x
                    local ty = it.y + cel.position.y
                    if inBounds(tx, ty) then 
                        lastCanvas:drawPixel(tx, ty, px) 
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- Core Symmetry Logic
----------------------------------------------------------------------
local function applySymmetry(ev)
    if ev and ev.fromUndo then 
        syncLastCanvas()
        return 
    end
    
    if isApplying then return end
    if not app.sprite or app.sprite ~= activeSprite then return end

    local layer = app.activeLayer
    local frame = app.activeFrame
    if not layer or not frame then return end

    local cel = layer:cel(frame)
    if not cel or not cel.image or cel.image.width == 0 then
        if lastCanvas then
            lastCanvas = Image(w, h, activeSprite.colorMode)
        end
        return
    end

    isApplying = true

    if activeSprite and siteListenerCode then
        activeSprite.events:off(siteListenerCode)
        siteListenerCode = nil
    end

    local success = pcall(function()
        local cimg = cel.image:clone()
        local cpos = cel.position
        local colorMode = cimg.colorMode
        local isEraserMode = (app.tool and app.tool.id == "eraser")

        local fullCanvas = Image(w, h, colorMode)
        for it in cimg:pixels() do
            local px = it()
            if px ~= 0 then
                local tx = it.x + cpos.x
                local ty = it.y + cpos.y
                if inBounds(tx, ty) then
                    fullCanvas:drawPixel(tx, ty, px)
                end
            end
        end

        local hasChanged = false
        local affectedPixels = {}
        local minX, minY, maxX, maxY = w, h, -1, -1

        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local oldPx = lastCanvas:getPixel(x, y)
                local newPx = fullCanvas:getPixel(x, y)
                if oldPx ~= 0 and newPx == 0 then
                    affectedPixels[x .. "_" .. y] = 0 
                    if x < minX then minX = x end
                    if y < minY then minY = y end
                    if x > maxX then maxX = x end
                    if y > maxY then maxY = y end
                end
            end
        end

        if not isEraserMode then
            for it in cimg:pixels() do
                local px = it()
                if px ~= 0 then
                    local canvasX = it.x + cpos.x
                    local canvasY = it.y + cpos.y

                    if inBounds(canvasX, canvasY) then
                        local oldPx = lastCanvas:getPixel(canvasX, canvasY)
                        if oldPx ~= px then
                            affectedPixels[canvasX .. "_" .. canvasY] = px
                            if canvasX < minX then minX = canvasX end
                            if canvasY < minY then minY = canvasY end
                            if canvasX > maxX then maxX = canvasX end
                            if canvasY > maxY then maxY = canvasY end
                        end
                    end
                end
            end

            if maxX >= 0 then
                for i = 1, symmetryOrder - 1 do
                    local tMinX, tMinY, tMaxX, tMaxY = w, h, -1, -1
                    local corners = {
                        {minX, minY}, {maxX, minY}, {minX, maxY}, {maxX, maxY}
                    }
                    for _, pt in ipairs(corners) do
                        local rx, ry = rotatePoint(pt[1], pt[2], i)
                        if rx < tMinX then tMinX = rx end
                        if ry < tMinY then tMinY = ry end
                        if rx > tMaxX then tMaxX = rx end
                        if ry > tMaxY then tMaxY = ry end
                    end

                    tMinX = math.max(0, tMinX - 1)
                    tMinY = math.max(0, tMinY - 1)
                    tMaxX = math.min(w - 1, tMaxX + 1)
                    tMaxY = math.min(h - 1, tMaxY + 1)

                    for ty = tMinY, tMaxY do
                        for tx = tMinX, tMaxX do
                            local origX, origY = rotatePointInverse(tx, ty, i)
                            local sourceColor = affectedPixels[origX .. "_" .. origY]
                            
                            if sourceColor then
                                if fullCanvas:getPixel(tx, ty) ~= sourceColor then
                                    fullCanvas:drawPixel(tx, ty, sourceColor)
                                    hasChanged = true
                                end
                            end
                        end
                    end
                end
            end
            
        else
            for y = 0, h - 1 do
                for x = 0, w - 1 do
                    local relX = x - cpos.x
                    local relY = y - cpos.y
                    local isCurrentlyEmpty = true

                    if relX >= 0 and relX < cimg.width and relY >= 0 and relY < cimg.height then
                        if cimg:getPixel(relX, relY) ~= 0 then
                            isCurrentlyEmpty = false
                        end
                    end

                    if isCurrentlyEmpty then
                        local oldPx = lastCanvas:getPixel(x, y)
                        if oldPx ~= 0 then
                            affectedPixels[x .. "_" .. y] = 0
                            if x < minX then minX = x end
                            if y < minY then minY = y end
                            if x > maxX then maxX = x end
                            if y > maxY then maxY = y end
                        end
                    end
                end
            end

            if maxX >= 0 then
                for i = 1, symmetryOrder - 1 do
                    local tMinX, tMinY, tMaxX, tMaxY = w, h, -1, -1
                    local corners = {
                        {minX, minY}, {maxX, minY}, {minX, maxY}, {maxX, maxY}
                    }
                    for _, pt in ipairs(corners) do
                        local rx, ry = rotatePoint(pt[1], pt[2], i)
                        if rx < tMinX then tMinX = rx end
                        if ry < tMinY then tMinY = ry end
                        if rx > tMaxX then tMaxX = rx end
                        if ry > tMaxY then tMaxY = ry end
                    end

                    tMinX = math.max(0, tMinX - 1)
                    tMinY = math.max(0, tMinY - 1)
                    tMaxX = math.min(w - 1, tMaxX + 1)
                    tMaxY = math.min(h - 1, tMaxY + 1)

                    for ty = tMinY, tMaxY do
                        for tx = tMinX, tMaxX do
                            local origX, origY = rotatePointInverse(tx, ty, i)
                            if affectedPixels[origX .. "_" .. origY] == 0 then
                                if fullCanvas:getPixel(tx, ty) ~= 0 then
                                    fullCanvas:drawPixel(tx, ty, 0)
                                    hasChanged = true
                                end
                            end
                        end
                    end
                end
            end
end
if hasChanged then
cel.image = fullCanvas
cel.position = Point(0, 0)
lastCanvas = fullCanvas:clone()
app.refresh()
else
lastCanvas = fullCanvas:clone()
end
end)
if activeSprite and not siteListenerCode then
siteListenerCode = activeSprite.events:on("change", function(newEv)
applySymmetry(newEv)
end)
end
isApplying = false
end

----------------------------------------------------------------------
-- UI Control & Event Binding
----------------------------------------------------------------------
local dialog = Dialog("Rotational Symmetry")

local function startScript()
    if isRunning then return end
    if not app.sprite then
        app.alert("No active sprite found.")
        return
    end
    activeSprite = app.sprite
    w = activeSprite.width
    h = activeSprite.height
    cx = w / 2
    cy = h / 2
    computeRotations()
    syncLastCanvas()
    siteListenerCode = activeSprite.events:on("change", function(ev)
        applySymmetry(ev)
    end)
    isRunning = true
    dialog:modify{ id="startBtn", enabled=false }
    dialog:modify{ id="stopBtn", enabled=true }
end

local function stopScript()
    if not isRunning then return end
    if activeSprite and siteListenerCode then
        activeSprite.events:off(siteListenerCode)
        siteListenerCode = nil
    end
    lastCanvas = nil
    isRunning = false
    dialog:modify{ id="startBtn", enabled=true }
    dialog:modify{ id="stopBtn", enabled=false }
end

dialog
    :slider{ 
        id="order", label="Symmetry Order (n):", min=2, max=32, value=4,
        onchange=function() symmetryOrder = dialog.data.order computeRotations() end 
    }
    :check{ 
        id="cw", label="Clockwise Rotation", selected=false,
        onchange=function() clockwise = dialog.data.cw computeRotations() end 
    }
    :separator()
    :button{ id="startBtn", text="Start", onclick=startScript }
    :button{ id="stopBtn", text="Stop", enabled=false, onclick=stopScript }
    :show{ wait=false }