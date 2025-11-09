-- Chompster
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local SoundManager = require("classes.SoundManager")
local Maze = require("classes.Maze")
local Chompster = require("classes.Chompster")
local ChaserAI = require("classes.ChaserAI")

local lg = love.graphics
local sqrt, min = math.sqrt, math.min

local Game = {}
Game.__index = Game

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

local function initGame(self, difficulty)
    self.difficulty = difficulty or "medium"
    self.maze = Maze.new(25, 25)
    self.player = Chompster.new(10, 10)

    -- Create chasers with different personalities
    self.chasers = {
        ChaserAI.new(8, 8, {0.9, 0.2, 0.2}, "normal"),     -- Red - Basic chaser
        ChaserAI.new(12, 8, {0.9, 0.6, 0.2}, "ambusher"),  -- Orange - Ambusher
        ChaserAI.new(8, 12, {0.2, 0.8, 0.9}, "patroller"), -- Cyan - Patroller
        ChaserAI.new(12, 12, {0.8, 0.2, 0.9}, "interceptor") -- Purple - Interceptor
    }

    self.gameOver = false
    self.won = false
    self.level = 1
    self.cellSize = min(screenWidth / (self.maze.width + 4), screenHeight / (self.maze.height + 4))
    self.offsetX = (screenWidth - self.maze.width * self.cellSize) * 0.5
    self.offsetY = (screenHeight - self.maze.height * self.cellSize) * 0.5
end

local function drawUI(self)
    -- Score and lives
    lg.setColor(1, 1, 1, 0.9)
    self.fonts:setFont("mediumFont")
    lg.print("Score: " .. self.player.score, 20, 20)
    lg.print("Lives: " .. self.player.lives, 20, 50)
    lg.print("Level: " .. self.level, 20, 80)
    lg.print("Difficulty: " .. self.difficulty:upper(), 20, 110)

    -- Dots remaining
    local dotsRemaining = self.maze:getRemainingDots()
    lg.print("Dots: " .. dotsRemaining, screenWidth - 150, 20)

    -- Power timer
    if self.player.powered then
        local timerWidth = 200
        local barWidth = (self.player.powerTimer / self.player.powerDuration) * timerWidth
        lg.setColor(1, 0.5, 0.8, 0.7)
        lg.rectangle("fill", screenWidth - timerWidth - 20, 50, barWidth, 20)
        lg.setColor(1, 1, 1, 0.8)
        lg.rectangle("line", screenWidth - timerWidth - 20, 50, timerWidth, 20)
    end

    if self.paused then
        lg.setColor(1, 0.8, 0.2, 0.9)
        lg.print("PAUSED - Press P or ESC to resume", screenWidth * 0.5 - 150, 40)
    end

    lg.setColor(1, 1, 1, 0.6)
    self.fonts:setFont("smallFont")
    lg.print("Press ESC for menu, P to pause", screenWidth - 250, screenHeight - 40)
end

local function drawGameOver(self)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local font = self.fonts:getFont("largeFont")
    self.fonts:setFont(font)
    lg.setColor(self.won and { 0.2, 0.8, 0.2 } or { 0.8, 0.2, 0.2 })
    lg.printf(self.won and "YOU WIN!" or "GAME OVER", 0, screenHeight / 2 - 80, screenWidth, "center")

    lg.setColor(1, 1, 1)
    self.fonts:setFont("mediumFont")
    lg.printf("Final Score: " .. self.player.score, 0, screenHeight / 2, screenWidth, "center")
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
    instance.sounds = SoundManager.new()

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

function Game:nextLevel()
    self.level = self.level + 1
    initGame(self, self.difficulty)
    -- Increase player speed slightly each level
    self.player.speed = self.player.speed + 0.1
end

function Game:handleKeyPress(key)
    if self.gameOver or self.paused then return end

    if key == "up" or key == "w" then
        self.player:setDirection(0, -1)
    elseif key == "down" or key == "s" then
        self.player:setDirection(0, 1)
    elseif key == "left" or key == "a" then
        self.player:setDirection(-1, 0)
    elseif key == "right" or key == "d" then
        self.player:setDirection(1, 0)
    end
end

function Game:screenResize()
    createPauseButtons(self)
    if self.maze then
        self.cellSize = min(screenWidth / (self.maze.width + 4), screenHeight / (self.maze.height + 4))
        self.offsetX = (screenWidth - self.maze.width * self.cellSize) * 0.5
        self.offsetY = (screenHeight - self.maze.height * self.cellSize) * 0.5
    end
end

function Game:startNewGame(difficulty)
    initGame(self, difficulty)
end

function Game:handleClick(x, y)
    if self.gameOver then return end
end

function Game:handlePauseClick(x, y)
    for _, button in ipairs(self.pauseButtons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            return button.action
        end
    end
end

function Game:checkCollisions()
    -- Check collision with chasers
    for _, chaser in ipairs(self.chasers) do
        if not chaser.dead then
            local dist = sqrt((self.player.x - chaser.x)^2 + (self.player.y - chaser.y)^2)
            if dist < 0.6 then -- Collision distance
                if chaser.vulnerable then
                    if chaser:kill() then
                        self.player:addPoints(200)
                    end
                else
                    if self.player:loseLife() then
                        self.player:resetPosition(10, 10)
                        -- Reset chasers
                        for _, c in ipairs(self.chasers) do
                            c:returnToStart()
                        end
                    else
                        self.gameOver = true
                        self.won = false
                    end
                    return
                end
            end
        end
    end

    -- Check dot collection
    if self.maze:collectDot(self.player.x, self.player.y) then
        self.player:addPoints(10)
    end

    -- Check power pellet collection
    if self.maze:collectPowerPellet(self.player.x, self.player.y) then
        self.player:activatePower()
        self.player:addPoints(50)
    end

    -- Check win condition
    if self.maze:getRemainingDots() == 0 then
        if self.level >= 3 then -- Win after 3 levels
            self.gameOver = true
            self.won = true
        else
            self:nextLevel()
        end
    end
end

function Game:update(dt)
    if not self.paused and not self.gameOver then
        self.player:update(dt, self.maze)

        for _, chaser in ipairs(self.chasers) do
            chaser:update(dt, self.maze, self.player, self.chasers, self.difficulty)
        end

        self:checkCollisions()
        self:updateButtonHover(love.mouse.getX(), love.mouse.getY())
    end
end

function Game:updateButtonHover(x, y)
    self.buttonHover = nil
    if self.gameOver or self.paused then return end
end

function Game:draw()
    lg.push()

    -- Draw maze and game elements
    if self.maze then
        self.maze:draw(self.cellSize, self.offsetX, self.offsetY)
        self.player:draw(self.cellSize, self.offsetX, self.offsetY)

        for _, chaser in ipairs(self.chasers) do
            chaser:draw(self.cellSize, self.offsetX, self.offsetY)
        end
    end

    drawUI(self)

    if self.gameOver then
        drawGameOver(self)
    elseif self.paused then
        drawPauseMenu(self)
    end

    lg.pop()
end

return Game
