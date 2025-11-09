-- Chompster
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random
local floor, abs, pi, insert = math.floor, math.abs, math.pi, table.insert

local Game = {}
Game.__index = Game

-- Game constants
local CELL_SIZE = 40
local PLAYER_SPEED = 2
local GHOST_SPEEDS = { easy = 1, medium = 1.5, hard = 2 }
local DOT_COUNT = 50
local POWERUP_COUNT = 4
local GHOST_COLORS = { { 0.9, 0.3, 0.3 }, { 0.3, 0.9, 0.3 }, { 0.3, 0.3, 0.9 }, { 0.9, 0.9, 0.3 } }
local DIRECTIONS = { { dx = 1, dy = 0 }, { dx = -1, dy = 0 }, { dx = 0, dy = 1 }, { dx = 0, dy = -1 } }

local function generateMaze(self)
    local maze = {}
    local width, height = floor(screenWidth / CELL_SIZE), floor(screenHeight / CELL_SIZE)

    -- Initialize empty maze
    for x = 1, width do
        maze[x] = {}
        for y = 1, height do
            maze[x][y] = { wall = false, dot = false, powerup = false }
        end
    end

    -- Create border walls
    for x = 1, width do
        maze[x][1].wall = true
        maze[x][height].wall = true
    end
    for y = 1, height do
        maze[1][y].wall = true
        maze[width][y].wall = true
    end

    -- Add random walls (fewer walls for more open space)
    for _ = 1, floor(width * height * 0.15) do
        local x, y = random(2, width - 1), random(2, height - 1)
        maze[x][y].wall = true
    end

    -- Add dots
    local dotsPlaced = 0
    while dotsPlaced < DOT_COUNT do
        local x, y = random(2, width - 1), random(2, height - 1)
        if not maze[x][y].wall and not maze[x][y].dot then
            maze[x][y].dot = true
            dotsPlaced = dotsPlaced + 1
        end
    end

    -- Add powerups
    local powerupsPlaced = 0
    while powerupsPlaced < POWERUP_COUNT do
        local x, y = random(2, width - 1), random(2, height - 1)
        if not maze[x][y].wall and not maze[x][y].dot and not maze[x][y].powerup then
            maze[x][y].powerup = true
            powerupsPlaced = powerupsPlaced + 1
        end
    end

    -- Find starting positions
    local startX, startY = floor(width / 2), floor(height / 2)
    while maze[startX][startY].wall do
        startX, startY = startX + 1, startY + 1
    end

    self.maze = maze
    self.mazeWidth = width
    self.mazeHeight = height
    self.startX, self.startY = startX, startY

    return startX, startY
end

local function createGhosts(self)
    self.ghosts = {}

    for i = 1, 4 do
        local x, y
        local attempts = 0
        repeat
            x, y = random(2, self.mazeWidth - 1), random(2, self.mazeHeight - 1)
            attempts = attempts + 1
            -- If we can't find a good spot after many attempts, just pick any non-wall spot
            if attempts > 50 then
                repeat
                    x, y = random(2, self.mazeWidth - 1), random(2, self.mazeHeight - 1)
                until not self.maze[x][y].wall
                break
            end
        until not self.maze[x][y].wall and (abs(x - self.player.x) > 5 or abs(y - self.player.y) > 5)

        self.ghosts[i] = {
            x = x,
            y = y,
            color = GHOST_COLORS[i],
            direction = random(1, 4),
            speed = GHOST_SPEEDS[self.difficulty],
            scared = false,
            scaredTimer = 0,
            moveCooldown = random(0.5, 2.0) -- Stagger ghost movement
        }
    end
end

local function isValidMove(self, x, y)
    local cellX, cellY = floor(x + 0.5), floor(y + 0.5)
    return cellX >= 1 and cellX <= self.mazeWidth and
        cellY >= 1 and cellY <= self.mazeHeight and
        not self.maze[cellX][cellY].wall
end

local function moveGhost(self, ghost, dt)
    if not self.player then return end

    -- Cooldown to slow down ghosts
    ghost.moveCooldown = ghost.moveCooldown - dt
    if ghost.moveCooldown > 0 then return end
    ghost.moveCooldown = random(0.3, 1.0) -- Reset cooldown

    -- Simple AI: chase player when not scared, run away when scared
    local targetX, targetY = self.player.x, self.player.y
    if ghost.scared then
        targetX, targetY = self.mazeWidth - targetX, self.mazeHeight - targetY
    end

    local possibleDirections = {}

    -- Check all possible directions
    for i, dir in ipairs(DIRECTIONS) do
        local newX, newY = ghost.x + dir.dx, ghost.y + dir.dy

        -- Don't allow reversing direction (more natural movement)
        local isOpposite = (i == 1 and ghost.direction == 2) or
            (i == 2 and ghost.direction == 1) or
            (i == 3 and ghost.direction == 4) or
            (i == 4 and ghost.direction == 3)

        if not isOpposite and isValidMove(self, newX, newY) then
            insert(possibleDirections, {
                index = i,
                x = newX,
                y = newY,
                distance = abs(newX - targetX) + abs(newY - targetY)
            })
        end
    end

    -- If no valid directions, try any direction (including opposite)
    if #possibleDirections == 0 then
        for i, dir in ipairs(DIRECTIONS) do
            local newX, newY = ghost.x + dir.dx, ghost.y + dir.dy
            if isValidMove(self, newX, newY) then
                insert(possibleDirections, {
                    index = i,
                    x = newX,
                    y = newY,
                    distance = abs(newX - targetX) + abs(newY - targetY)
                })
            end
        end
    end

    if #possibleDirections > 0 then
        -- Choose best direction based on scared state
        local bestDir
        if ghost.scared then
            -- When scared, prefer directions that are farther from player
            bestDir = possibleDirections[1]
            for _, dir in ipairs(possibleDirections) do
                if dir.distance > bestDir.distance then
                    bestDir = dir
                end
            end
        else
            -- When not scared, prefer directions that are closer to player
            bestDir = possibleDirections[1]
            for _, dir in ipairs(possibleDirections) do
                if dir.distance < bestDir.distance then
                    bestDir = dir
                end
            end
        end

        ghost.direction = bestDir.index
        ghost.x = bestDir.x
        ghost.y = bestDir.y
    end
end

local function checkCollisions(self)
    if not self.player then return end

    local playerCellX, playerCellY = floor(self.player.x + 0.5), floor(self.player.y + 0.5)

    -- Check dot collection
    if self.maze[playerCellX][playerCellY].dot then
        self.maze[playerCellX][playerCellY].dot = false
        self.score = self.score + 10
        self.dotsCollected = self.dotsCollected + 1
    end

    -- Check powerup collection
    if self.maze[playerCellX][playerCellY].powerup then
        self.maze[playerCellX][playerCellY].powerup = false
        self.score = self.score + 50
        self.powerupActive = true
        self.powerupTimer = 5 -- 5 seconds

        -- Make ghosts scared
        for _, ghost in ipairs(self.ghosts) do
            ghost.scared = true
            ghost.scaredTimer = 5
        end
    end

    -- Check ghost collisions
    for _, ghost in ipairs(self.ghosts) do
        local ghostCellX, ghostCellY = floor(ghost.x + 0.5), floor(ghost.y + 0.5)

        if playerCellX == ghostCellX and playerCellY == ghostCellY then
            if ghost.scared then
                -- Eat ghost
                ghost.x, ghost.y = self.startX, self.startY
                ghost.scared = false
                ghost.scaredTimer = 0
                self.score = self.score + 200
            else
                -- Lose life
                self.lives = self.lives - 1
                if self.lives <= 0 then
                    self.gameOver = true
                    self.won = false
                else
                    -- Reset positions with more space between player and ghosts
                    self.player.x, self.player.y = self.startX, self.startY
                    for _, g in ipairs(self.ghosts) do
                        local attempts = 0
                        repeat
                            g.x, g.y = random(2, self.mazeWidth - 1), random(2, self.mazeHeight - 1)
                            attempts = attempts + 1
                            if attempts > 50 then
                                repeat
                                    g.x, g.y = random(2, self.mazeWidth - 1), random(2, self.mazeHeight - 1)
                                until not self.maze[g.x][g.y].wall
                                break
                            end
                        until not self.maze[g.x][g.y].wall and (abs(g.x - self.player.x) > 5 or abs(g.y - self.player.y) > 5)
                    end
                end
            end
        end
    end

    -- Check win condition
    if self.dotsCollected >= DOT_COUNT then
        self.gameOver = true
        self.won = true
        self.score = self.score + self.lives * 100
    end
end

local function createPauseButtons(self)
    local centerX, centerY = screenWidth * 0.5, screenHeight * 0.5
    self.pauseButtons = {
        {
            text = "Resume",
            action = "resume",
            x = centerX - 100,
            y = centerY - 60,
            width = 200,
            height = 50,
            color = { 0.2, 0.7, 0.3 }
        },
        {
            text = "Restart",
            action = "restart",
            x = centerX - 100,
            y = centerY + 10,
            width = 200,
            height = 50,
            color = { 0.9, 0.7, 0.2 }
        },
        {
            text = "Main Menu",
            action = "menu",
            x = centerX - 100,
            y = centerY + 80,
            width = 200,
            height = 50,
            color = { 0.8, 0.3, 0.3 }
        }
    }
end

local function updatePauseButtonHover(self, x, y)
    self.pauseButtonHover = nil
    for _, button in ipairs(self.pauseButtons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            self.pauseButtonHover = button.action
            return
        end
    end
end

local function drawUI(self)
    -- Score
    lg.setColor(1, 1, 1, 0.9)
    self.fonts:setFont("mediumFont")
    lg.print("Score: " .. (self.score or 0), 20, 20)

    -- Lives
    lg.print("Lives: " .. (self.lives or 0), 20, 60)

    -- Difficulty
    lg.print("Difficulty: " .. (self.difficulty or "medium"):upper(), 20, 100)

    -- Powerup timer
    if self.powerupActive then
        lg.setColor(0.8, 0.2, 0.8, 0.9)
        lg.print("POWER: " .. string.format("%.1f", self.powerupTimer or 0), 20, 140)
    end

    -- Dots collected
    lg.setColor(1, 1, 1, 0.9)
    lg.print("Dots: " .. (self.dotsCollected or 0) .. "/" .. DOT_COUNT, 20, 180)

    if self.paused then
        lg.setColor(1, 0.8, 0.2, 0.9)
        lg.print("PAUSED - Press P or ESC to resume", screenWidth * 0.5 - 150, 40)
    end
end

local function drawMaze(self)
    if not self.maze then return end

    for x = 1, self.mazeWidth do
        for y = 1, self.mazeHeight do
            local cell = self.maze[x][y]
            local screenX, screenY = (x - 1) * CELL_SIZE, (y - 1) * CELL_SIZE

            if cell.wall then
                lg.setColor(0.2, 0.3, 0.8, 0.8)
                lg.rectangle("fill", screenX, screenY, CELL_SIZE, CELL_SIZE)
            elseif cell.dot then
                lg.setColor(1, 1, 1, 0.8)
                lg.circle("fill", screenX + CELL_SIZE / 2, screenY + CELL_SIZE / 2, 4)
            elseif cell.powerup then
                lg.setColor(0.8, 0.2, 0.8, 0.9)
                lg.circle("fill", screenX + CELL_SIZE / 2, screenY + CELL_SIZE / 2, 6)
            end
        end
    end
end

local function drawPlayer(self)
    if not self.player then return end

    local x, y = (self.player.x - 1) * CELL_SIZE, (self.player.y - 1) * CELL_SIZE

    -- Draw Chompster (circular character with mouth)
    lg.setColor(1, 0.8, 0.2, 0.9) -- Yellow-orange
    lg.circle("fill", x + CELL_SIZE / 2, y + CELL_SIZE / 2, CELL_SIZE / 2 - 2)

    -- Mouth based on direction
    lg.setColor(0, 0, 0, 1)
    local mouthAngle = 0.3
    if self.player.direction == 1 then     -- Right
        lg.arc("fill", x + CELL_SIZE / 2, y + CELL_SIZE / 2, CELL_SIZE / 3, -mouthAngle, mouthAngle)
    elseif self.player.direction == 2 then -- Left
        lg.arc("fill", x + CELL_SIZE / 2, y + CELL_SIZE / 2, CELL_SIZE / 3, pi - mouthAngle, pi + mouthAngle)
    elseif self.player.direction == 3 then -- Down
        lg.arc("fill", x + CELL_SIZE / 2, y + CELL_SIZE / 2, CELL_SIZE / 3, pi / 2 - mouthAngle,
            pi / 2 + mouthAngle)
    else -- Up
        lg.arc("fill", x + CELL_SIZE / 2, y + CELL_SIZE / 2, CELL_SIZE / 3, -pi / 2 - mouthAngle,
            -pi / 2 + mouthAngle)
    end
end

local function drawGhosts(self)
    if not self.ghosts then return end

    for _, ghost in ipairs(self.ghosts) do
        local x, y = (ghost.x - 1) * CELL_SIZE, (ghost.y - 1) * CELL_SIZE

        if ghost.scared then
            lg.setColor(0.3, 0.3, 1, 0.9) -- Blue when scared
        else
            lg.setColor(ghost.color[1], ghost.color[2], ghost.color[3], 0.9)
        end

        -- Ghost body (semi-circle with wavy bottom)
        lg.circle("fill", x + CELL_SIZE / 2, y + CELL_SIZE / 2, CELL_SIZE / 2 - 2)

        -- Ghost eyes
        lg.setColor(1, 1, 1, 1)
        lg.circle("fill", x + CELL_SIZE / 2 - 5, y + CELL_SIZE / 2 - 3, 3)
        lg.circle("fill", x + CELL_SIZE / 2 + 5, y + CELL_SIZE / 2 - 3, 3)

        lg.setColor(0, 0, 0, 1)
        lg.circle("fill", x + CELL_SIZE / 2 - 5, y + CELL_SIZE / 2 - 3, 1.5)
        lg.circle("fill", x + CELL_SIZE / 2 + 5, y + CELL_SIZE / 2 - 3, 1.5)
    end
end

local function drawGameOver(self)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local font = self.fonts:getFont("largeFont")
    self.fonts:setFont(font)
    lg.setColor(self.won and { 0.2, 0.8, 0.2 } or { 0.8, 0.2, 0.2 })
    lg.printf(self.won and "VICTORY!" or "GAME OVER", 0, screenHeight / 2 - 80, screenWidth, "center")

    lg.setColor(1, 1, 1)
    self.fonts:setFont("mediumFont")
    lg.printf("Final Score: " .. (self.score or 0), 0, screenHeight / 2, screenWidth, "center")
    lg.printf("Click anywhere to continue", 0, screenHeight / 2 + 60, screenWidth, "center")
end

local function drawPauseMenu(self)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    lg.setColor(1, 1, 1)
    self.fonts:setFont("largeFont")
    lg.printf("PAUSED", 0, screenHeight * 0.3, screenWidth, "center")

    for _, button in ipairs(self.pauseButtons) do
        local isHovered = self.pauseButtonHover == button.action
        local r, g, b = unpack(button.color)

        lg.setColor(r, g, b, isHovered and 0.9 or 0.7)
        lg.rectangle("fill", button.x, button.y, button.width, button.height, 10)

        lg.setColor(1, 1, 1, isHovered and 1 or 0.8)
        lg.setLineWidth(isHovered and 3 or 2)
        lg.rectangle("line", button.x, button.y, button.width, button.height, 10)

        lg.setColor(1, 1, 1)
        self.fonts:setFont("mediumFont")
        local textWidth = self.fonts:getFont("mediumFont"):getWidth(button.text)
        local textHeight = self.fonts:getFont("mediumFont"):getHeight()
        lg.print(button.text, button.x + (button.width - textWidth) * 0.5, button.y + (button.height - textHeight) * 0.5)
    end
    lg.setLineWidth(1)
end

function Game.new(fontManager)
    local instance = setmetatable({}, Game)

    instance.fonts = fontManager
    instance.gameOver = false
    instance.won = false
    instance.difficulty = "medium"
    instance.paused = false
    instance.buttonHover = nil
    instance.pauseButtonHover = nil

    -- Initialize game state variables
    instance.score = 0
    instance.lives = 3
    instance.dotsCollected = 0
    instance.powerupActive = false
    instance.powerupTimer = 0

    createPauseButtons(instance)
    return instance
end

function Game:isGameOver() return self.gameOver end

function Game:isPaused() return self.paused end

function Game:setPaused(paused)
    self.paused = paused
    if paused then
        updatePauseButtonHover(self, love.mouse.getX(), love.mouse.getY())
    end
end

function Game:screenResize()
    createPauseButtons(self)
    if self.maze then
        self.mazeWidth = floor(screenWidth / CELL_SIZE)
        self.mazeHeight = floor(screenHeight / CELL_SIZE)
    end
end

function Game:startNewGame(difficulty)
    self.difficulty = difficulty or "medium"
    self.gameOver = false
    self.won = false
    self.paused = false
    self.score = 0
    self.lives = 3
    self.dotsCollected = 0
    self.powerupActive = false
    self.powerupTimer = 0

    local startX, startY = generateMaze(self)

    self.player = {
        x = startX,
        y = startY,
        direction = 1, -- 1: right, 2: left, 3: down, 4: up
        nextDirection = 1,
        speed = PLAYER_SPEED
    }

    createGhosts(self)
end

function Game:handleClick(x, y)
    if self.gameOver then
        return
    end

    if self.paused then return end
end

function Game:handlePauseClick(x, y)
    for _, button in ipairs(self.pauseButtons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            return button.action
        end
    end
end

function Game:update(dt)
    if self.paused or self.gameOver then return end

    -- Don't update if game isn't properly initialized
    if not self.player or not self.ghosts or not self.maze then return end

    -- Update powerup timer
    if self.powerupActive then
        self.powerupTimer = self.powerupTimer - dt
        if self.powerupTimer <= 0 then
            self.powerupActive = false
            for _, ghost in ipairs(self.ghosts) do
                ghost.scared = false
                ghost.scaredTimer = 0
            end
        end
    end

    -- Update player movement
    local dir = self.player.nextDirection
    local dx, dy = 0, 0

    if dir == 1 then
        dx = 1
    elseif dir == 2 then
        dx = -1
    elseif dir == 3 then
        dy = 1
    elseif dir == 4 then
        dy = -1
    end

    local newX, newY = self.player.x + dx * self.player.speed * dt, self.player.y + dy * self.player.speed * dt

    -- Check if movement is valid
    if isValidMove(self, newX, newY) then
        self.player.x, self.player.y = newX, newY
        self.player.direction = dir
    else
        -- Try current direction if next direction is blocked
        dir = self.player.direction
        dx, dy = 0, 0

        if dir == 1 then
            dx = 1
        elseif dir == 2 then
            dx = -1
        elseif dir == 3 then
            dy = 1
        elseif dir == 4 then
            dy = -1
        end

        newX, newY = self.player.x + dx * self.player.speed * dt, self.player.y + dy * self.player.speed * dt

        if isValidMove(self, newX, newY) then
            self.player.x, self.player.y = newX, newY
        end
    end

    -- Update ghosts
    for _, ghost in ipairs(self.ghosts) do
        if ghost.scared then
            ghost.scaredTimer = ghost.scaredTimer - dt
            if ghost.scaredTimer <= 0 then
                ghost.scared = false
                ghost.scaredTimer = 0
            end
        end
        moveGhost(self, ghost, dt)
    end

    checkCollisions(self)
end

function Game:updateButtonHover(x, y)
    self.buttonHover = nil
    if self.gameOver or self.paused then return end
end

function Game:draw()
    lg.push()

    -- Draw game elements
    drawMaze(self)
    drawPlayer(self)
    drawGhosts(self)
    drawUI(self)

    if self.gameOver then
        drawGameOver(self)
    elseif self.paused then
        drawPauseMenu(self)
    end

    lg.pop()
end

function Game:keypressed(key)
    if self.gameOver or self.paused then return end
    if not self.player then return end

    if key == "right" or key == "d" then
        self.player.nextDirection = 1
    elseif key == "left" or key == "a" then
        self.player.nextDirection = 2
    elseif key == "down" or key == "s" then
        self.player.nextDirection = 3
    elseif key == "up" or key == "w" then
        self.player.nextDirection = 4
    end
end

return Game
