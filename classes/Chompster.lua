-- Chompster
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local sin, floor = math.sin, math.floor

local Chompster = {}
Chompster.__index = Chompster

function Chompster.new(startX, startY)
    local instance = setmetatable({}, Chompster)
    instance.x = startX
    instance.y = startY
    instance.speed = 2
    instance.direction = { x = 0, y = 0 }
    instance.nextDirection = { x = 0, y = 0 }
    instance.radius = 0.3
    instance.powered = false
    instance.powerTimer = 0
    instance.powerDuration = 8
    instance.lives = 3
    instance.score = 0
    return instance
end

function Chompster:update(dt, maze)
    -- Handle power pellet timer
    if self.powered then
        self.powerTimer = self.powerTimer - dt
        if self.powerTimer <= 0 then
            self.powered = false
        end
    end

    -- Try to change direction if requested
    if self.nextDirection.x ~= 0 or self.nextDirection.y ~= 0 then
        local nextX = self.x + self.nextDirection.x
        local nextY = self.y + self.nextDirection.y

        if maze:getCell(floor(nextX + 0.5), floor(nextY + 0.5)) == 0 then
            self.direction.x = self.nextDirection.x
            self.direction.y = self.nextDirection.y
            self.nextDirection.x = 0
            self.nextDirection.y = 0
        end
    end

    -- Move in current direction
    if self.direction.x ~= 0 or self.direction.y ~= 0 then
        local nextX = self.x + self.direction.x * self.speed * dt
        local nextY = self.y + self.direction.y * self.speed * dt

        if maze:getCell(floor(nextX + 0.5), floor(nextY + 0.5)) == 0 then
            self.x = nextX
            self.y = nextY
        else
            -- Stop if we hit a wall
            self.direction.x = 0
            self.direction.y = 0
        end
    end

    -- Wrap around edges (teleport)
    if self.x < 1 then
        self.x = maze.width
    elseif self.x > maze.width then
        self.x = 1
    end
end

function Chompster:setDirection(dirX, dirY)
    self.nextDirection.x = dirX
    self.nextDirection.y = dirY
end

function Chompster:activatePower()
    self.powered = true
    self.powerTimer = self.powerDuration
end

function Chompster:loseLife()
    self.lives = self.lives - 1
    return self.lives > 0
end

function Chompster:addPoints(points)
    self.score = self.score + points
end

function Chompster:resetPosition(startX, startY)
    self.x = startX
    self.y = startY
    self.direction = { x = 0, y = 0 }
    self.nextDirection = { x = 0, y = 0 }
    self.powered = false
    self.powerTimer = 0
end

function Chompster:draw(cellSize, offsetX, offsetY)
    local screenX = offsetX + self.x * cellSize
    local screenY = offsetY + self.y * cellSize

    -- Draw chompster body
    if self.powered then
        local time = love.timer.getTime()
        local pulse = (sin(time * 10) + 1) * 0.3 + 0.4
        lg.setColor(1, pulse, pulse)
    else
        lg.setColor(1, 0.8, 0.2) -- Yellow-orange color
    end

    lg.circle("fill", screenX, screenY, self.radius * cellSize)

    -- Draw eyes
    lg.setColor(1, 1, 1)
    local eyeOffset = self.radius * cellSize * 0.4
    local eyeSize = self.radius * cellSize * 0.3

    -- Eye direction based on movement
    local eyeDX, eyeDY = self.direction.x, self.direction.y
    if eyeDX == 0 and eyeDY == 0 then
        eyeDX, eyeDY = 1, 0 -- Default to right
    end

    lg.circle("fill", screenX + eyeDX * eyeOffset, screenY + eyeDY * eyeOffset, eyeSize)
end

return Chompster
