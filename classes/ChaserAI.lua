-- Chompster
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random
local huge, sqrt, floor, sin, cos, insert = math.huge, math.sqrt, math.floor, math.sin, math.cos, table.insert

local ChaserAI = {}
ChaserAI.__index = ChaserAI

function ChaserAI.new(startX, startY, color, personality)
    local instance = setmetatable({}, ChaserAI)
    instance.x = startX
    instance.y = startY
    instance.speed = 1.8
    instance.direction = { x = 0, y = 0 }
    instance.color = color
    instance.personality = personality or "normal"
    instance.radius = 0.3
    instance.vulnerable = false
    instance.dead = false
    instance.respawnTimer = 0
    instance.respawnTime = 3
    instance.targetX = startX
    instance.targetY = startY
    return instance
end

function ChaserAI:update(dt, maze, player, otherChasers, difficulty)
    if self.dead then
        self.respawnTimer = self.respawnTimer - dt
        if self.respawnTimer <= 0 then
            self.dead = false
            self.vulnerable = false
            self:returnToStart()
        end
        return
    end

    -- Become vulnerable if player is powered up
    self.vulnerable = player.powered

    -- Adjust speed based on difficulty and state
    local currentSpeed = self.speed
    if self.vulnerable then
        currentSpeed = currentSpeed * 0.6 -- Slower when vulnerable
    elseif difficulty == "hard" then
        currentSpeed = currentSpeed * 1.2
    elseif difficulty == "easy" then
        currentSpeed = currentSpeed * 0.8
    end

    -- Choose target based on personality and state
    if self.vulnerable then
        -- Run away from player when vulnerable
        self.targetX = self.x * 2 - player.x
        self.targetY = self.y * 2 - player.y
    else
        if self.personality == "ambusher" then
            -- Target position ahead of player
            self.targetX = player.x + player.direction.x * 4
            self.targetY = player.y + player.direction.y * 4
        elseif self.personality == "patroller" then
            -- Switch between targeting player and patrolling
            if random() < 0.7 then
                self.targetX = player.x
                self.targetY = player.y
            else
                -- Patrol specific areas
                local time = love.timer.getTime()
                self.targetX = 10 + sin(time) * 5
                self.targetY = 10 + cos(time) * 5
            end
        elseif self.personality == "interceptor" then
            -- Try to intercept player's path
            local predictedX = player.x + player.direction.x * 3
            local predictedY = player.y + player.direction.y * 3
            self.targetX = (player.x + predictedX) / 2
            self.targetY = (player.y + predictedY) / 2
        else -- normal
            self.targetX = player.x
            self.targetY = player.y
        end
    end

    -- Choose next move
    local bestDirection = self:chooseDirection(maze, difficulty, otherChasers)

    if bestDirection then
        self.direction.x = bestDirection[1]
        self.direction.y = bestDirection[2]
    end

    local nextX = self.x + self.direction.x * currentSpeed * dt
    local nextY = self.y + self.direction.y * currentSpeed * dt

    if self:isValidMove(maze, nextX, nextY) then
        self.x = nextX
        self.y = nextY
    end

    -- Wrap around edges
    if self.x < 1 then
        self.x = maze.width
    elseif self.x > maze.width then
        self.x = 1
    end
end

function ChaserAI:isValidMove(maze, x, y)
    -- Check the center cell
    local centerCellX, centerCellY = math.floor(x + 0.5), math.floor(y + 0.5)
    if maze:getCell(centerCellX, centerCellY) ~= 0 then return false end

    -- Check adjacent cells based on entity radius
    local radius = self.radius

    local checkPositions = {
        {x - radius, y},
        {x + radius, y},
        {x, y - radius},
        {x, y + radius}
    }

    for _, pos in ipairs(checkPositions) do
        local checkX, checkY = math.floor(pos[1] + 0.5), math.floor(pos[2] + 0.5)
        if maze:getCell(checkX, checkY) ~= 0 then return false end
    end

    return true
end

function ChaserAI:chooseDirection(maze, difficulty, otherChasers)
    local possibleDirections = {}
    local currentCellX, currentCellY = floor(self.x + 0.5), floor(self.y + 0.5)

    -- Check all four directions
    for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local dx, dy = dir[1], dir[2]

        -- Don't allow immediate reversal (more natural movement)
        if not (dx == -self.direction.x and dy == -self.direction.y) then
            local nextX, nextY = currentCellX + dx, currentCellY + dy
            if maze:getCell(nextX, nextY) == 0 then
                insert(possibleDirections, { dx, dy })
            end
        end
    end

    if #possibleDirections == 0 then
        -- If no other options, allow reversal
        for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local dx, dy = dir[1], dir[2]
            local nextX, nextY = currentCellX + dx, currentCellY + dy
            if maze:getCell(nextX, nextY) == 0 then
                insert(possibleDirections, { dx, dy })
            end
        end
    end

    if #possibleDirections == 0 then return nil end

    -- AI behavior based on difficulty and state
    if difficulty == "easy" then
        -- More random movement
        if random() < 0.3 then
            return possibleDirections[random(#possibleDirections)]
        end
    elseif difficulty == "hard" and not self.vulnerable then
        -- Strategic movement - avoid other chasers
        local bestScore = -huge
        local bestDir = possibleDirections[1]

        for _, dir in ipairs(possibleDirections) do
            local dx, dy = dir[1], dir[2]
            local score = 0

            -- Distance to target (inverse)
            local distToTarget = sqrt((self.targetX - (self.x + dx)) ^ 2 + (self.targetY - (self.y + dy)) ^ 2)
            score = score - distToTarget * (self.vulnerable and 1 or -1) -- Positive when vulnerable (run away)

            -- Avoid other chasers (when not vulnerable)
            if not self.vulnerable and otherChasers then
                for _, other in ipairs(otherChasers) do
                    if other ~= self and not other.dead then
                        local distToOther = sqrt((other.x - (self.x + dx)) ^ 2 + (other.y - (self.y + dy)) ^ 2)
                        if distToOther < 2 then
                            score = score - 5
                        end
                    end
                end
            end

            if score > bestScore then
                bestScore = score
                bestDir = dir
            end
        end
        return bestDir
    end

    -- Medium/default behavior - move toward target with some randomness
    local bestDist = huge
    local bestDir = possibleDirections[1]

    for _, dir in ipairs(possibleDirections) do
        local dx, dy = dir[1], dir[2]
        local dist = sqrt((self.targetX - (self.x + dx)) ^ 2 + (self.targetY - (self.y + dy)) ^ 2)

        if dist < bestDist then
            bestDist = dist
            bestDir = dir
        end
    end

    return bestDir
end

function ChaserAI:kill()
    if self.vulnerable and not self.dead then
        self.dead = true
        self.respawnTimer = self.respawnTime
        return true
    end
    return false
end

function ChaserAI:returnToStart()
    -- Override this with actual start position
    self.x = 10
    self.y = 10
    self.direction = { x = 0, y = 0 }
end

function ChaserAI:draw(cellSize, offsetX, offsetY)
    if self.dead then return end

    local screenX = offsetX + self.x * cellSize
    local screenY = offsetY + self.y * cellSize

    -- Draw chaser body
    if self.vulnerable then
        local time = love.timer.getTime()
        local pulse = (sin(time * 8) + 1) * 0.3 + 0.4
        lg.setColor(0.3, pulse, 1) -- Blue pulsing when vulnerable
    else
        lg.setColor(self.color[1], self.color[2], self.color[3])
    end

    lg.circle("fill", screenX, screenY, self.radius * cellSize)

    -- Draw eyes (only when not vulnerable)
    if not self.vulnerable then
        lg.setColor(1, 1, 1)
        local eyeOffset = self.radius * cellSize * 0.4
        local eyeSize = self.radius * cellSize * 0.2

        -- Eyes look in direction of movement
        local eyeDX, eyeDY = self.direction.x, self.direction.y
        if eyeDX == 0 and eyeDY == 0 then
            eyeDX, eyeDY = 1, 0 -- Default to right
        end

        lg.circle("fill", screenX + eyeDX * eyeOffset, screenY + eyeDY * eyeOffset, eyeSize)
    end
end

return ChaserAI
