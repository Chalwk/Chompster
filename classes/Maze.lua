-- Chompster
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Maze = {}
Maze.__index = Maze

local ipairs = ipairs
local lg, random = love.graphics, love.math.random
local floor, insert, remove = math.floor, table.insert, table.remove

-- right, left, down, up
local DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

function Maze.new(width, height)
    local instance = setmetatable({}, Maze)
    instance.width = width
    instance.height = height
    instance.cells = {}
    instance.dots = {}
    instance.powerPellets = {}
    instance:generate()
    return instance
end

function Maze:generate()
    -- Initialize all cells as walls
    for x = 1, self.width do
        self.cells[x] = {}
        for y = 1, self.height do
            self.cells[x][y] = 1 -- 1 = wall, 0 = path
        end
    end

    -- Use randomized DFS to generate maze
    local stack = {}
    local startX, startY = 2, 2
    self.cells[startX][startY] = 0
    insert(stack, { startX, startY })

    while #stack > 0 do
        local current = stack[#stack]
        local x, y = current[1], current[2]

        -- Get unvisited neighbors
        local neighbors = {}
        for _, dir in ipairs(DIRECTIONS) do
            local nx, ny = x + dir[1] * 2, y + dir[2] * 2
            if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height and self.cells[nx][ny] == 1 then
                insert(neighbors, { nx, ny, dir[1], dir[2] })
            end
        end

        if #neighbors > 0 then
            local nextCell = neighbors[random(#neighbors)]
            local nx, ny, dx, dy = nextCell[1], nextCell[2], nextCell[3], nextCell[4]

            -- Carve path
            self.cells[x + dx][y + dy] = 0
            self.cells[nx][ny] = 0

            insert(stack, { nx, ny })
        else
            remove(stack)
        end
    end

    -- Create borders
    for x = 1, self.width do
        self.cells[x][1] = 1
        self.cells[x][self.height] = 1
    end
    for y = 1, self.height do
        self.cells[1][y] = 1
        self.cells[self.width][y] = 1
    end

    -- Place dots and power pellets
    self:placeCollectibles()
end

function Maze:placeCollectibles()
    self.dots = {}
    self.powerPellets = {}

    for x = 2, self.width - 1 do
        for y = 2, self.height - 1 do
            if self.cells[x][y] == 0 then
                -- Don't place dots in starting area
                if not (x >= 8 and x <= 12 and y >= 8 and y <= 12) then
                    insert(self.dots, { x = x, y = y, collected = false })
                end
            end
        end
    end

    -- Place power pellets in corners
    local corners = {
        { 3, 3 }, { self.width - 2, 3 },
        { 3, self.height - 2 }, { self.width - 2, self.height - 2 }
    }
    for _, corner in ipairs(corners) do
        if self.cells[corner[1]][corner[2]] == 0 then
            insert(self.powerPellets, { x = corner[1], y = corner[2], collected = false })
        end
    end
end

function Maze:getCell(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then
        return 1 -- wall
    end
    return self.cells[x][y]
end

function Maze:collectDot(x, y)
    for _, dot in ipairs(self.dots) do
        if floor(dot.x) == floor(x) and floor(dot.y) == floor(y) and not dot.collected then
            dot.collected = true
            return true
        end
    end
    return false
end

function Maze:collectPowerPellet(x, y)
    for i, pellet in ipairs(self.powerPellets) do
        if floor(pellet.x) == floor(x) and floor(pellet.y) == floor(y) and not pellet.collected then
            pellet.collected = true
            return true
        end
    end
    return false
end

function Maze:getRemainingDots()
    local count = 0
    for _, dot in ipairs(self.dots) do
        if not dot.collected then count = count + 1 end
    end
    return count
end

function Maze:draw(cellSize, offsetX, offsetY)

    -- Draw walls
    lg.setColor(0.2, 0.3, 0.8)
    for x = 1, self.width do
        for y = 1, self.height do
            if self.cells[x][y] == 1 then
                lg.rectangle("fill", offsetX + (x - 1) * cellSize, offsetY + (y - 1) * cellSize, cellSize, cellSize)
            end
        end
    end

    -- Draw dots
    lg.setColor(1, 1, 0.8)
    for _, dot in ipairs(self.dots) do
        if not dot.collected then
            lg.circle("fill", offsetX + dot.x * cellSize - cellSize / 2, offsetY + dot.y * cellSize - cellSize / 2,
                cellSize / 8)
        end
    end

    -- Draw power pellets
    lg.setColor(1, 0.5, 0.8)
    for _, pellet in ipairs(self.powerPellets) do
        if not pellet.collected then
            lg.circle("fill", offsetX + pellet.x * cellSize - cellSize / 2, offsetY + pellet.y * cellSize - cellSize / 2,
                cellSize / 4)
        end
    end
end

return Maze
