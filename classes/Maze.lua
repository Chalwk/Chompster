-- Chompster
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Maze = {}
Maze.__index = Maze

local ipairs = ipairs
local insert = table.insert
local lg, random = love.graphics, love.math.random

local DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Offsets for power pellets
local CORNER_OFFSETS = { { 3, 3 }, { -2, 3 }, { 3, -2 }, { -2, -2 } }

-- Colors
local WALL_COLOR = { 0.2, 0.3, 0.8 }
local DOT_COLOR = { 1, 1, 0.8 }
local PELLET_COLOR = { 1, 0.5, 0.8 }

local function placeCollectibles(self)
    self.dots = {}
    self.powerPellets = {}

    local dots, powerPellets = self.dots, self.powerPellets
    local cells, width, height = self.cells, self.width, self.height

    -- Starting area boundaries
    local startXMin, startXMax = 8, 12
    local startYMin, startYMax = 8, 12

    -- Iterate through all valid cells for dots
    for x = 2, width - 1 do
        for y = 2, height - 1 do
            if cells[x][y] == 0 then
                -- Skip starting area
                if not (x >= startXMin and x <= startXMax and y >= startYMin and y <= startYMax) then
                    insert(dots, { x = x, y = y, collected = false })
                end
            end
        end
    end

    -- Place power pellets in corners
    for i = 1, 4 do
        local corner = CORNER_OFFSETS[i]
        local x, y

        if corner[1] > 0 then
            x = corner[1]
        else
            x = width + corner[1]
        end

        if corner[2] > 0 then
            y = corner[2]
        else
            y = height + corner[2]
        end

        if cells[x][y] == 0 then
            insert(powerPellets, { x = x, y = y, collected = false })
        end
    end
end

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
    local width, height = self.width, self.height
    local cells = self.cells

    -- Initialize all cells as walls
    for x = 1, width do
        cells[x] = {}
        for y = 1, height do
            cells[x][y] = 1 -- 1 = wall, 0 = path
        end
    end

    -- Use iterative Depth First Search (DFS) for maze generation
    local stack = {}
    local startX, startY = 2, 2
    cells[startX][startY] = 0
    insert(stack, { startX, startY })

    while #stack > 0 do
        local current = stack[#stack]
        local x, y = current[1], current[2]

        -- Get unvisited neighbors
        local neighbors = {}
        for _, dir in ipairs(DIRECTIONS) do
            local nx, ny = x + dir[1] * 2, y + dir[2] * 2
            if nx >= 1 and nx <= width and ny >= 1 and ny <= height and cells[nx][ny] == 1 then
                insert(neighbors, { nx, ny, dir[1], dir[2] })
            end
        end

        if #neighbors > 0 then
            local nextCell = neighbors[random(#neighbors)]
            local nx, ny, dx, dy = nextCell[1], nextCell[2], nextCell[3], nextCell[4]

            -- Carve path
            cells[x + dx][y + dy] = 0
            cells[nx][ny] = 0

            insert(stack, { nx, ny })
        else
            stack[#stack] = nil
        end
    end

    -- Create borders
    for x = 1, width do
        cells[x][1] = 1
        cells[x][height] = 1
    end
    for y = 1, height do
        cells[1][y] = 1
        cells[width][y] = 1
    end

    -- Place collectibles
    placeCollectibles(self)
end

function Maze:getCell(x, y)
    -- Out of bounds check
    if x < 1 or x > self.width or y < 1 or y > self.height then return 1 end
    return self.cells[x][y]
end

function Maze:draw(cellSize, offsetX, offsetY)
    local cells, dots, powerPellets = self.cells, self.dots, self.powerPellets
    local width, height = self.width, self.height

    local halfCell = cellSize / 2
    local dotRadius = cellSize / 8
    local pelletRadius = cellSize / 4

    -- Draw walls
    lg.setColor(WALL_COLOR)
    for x = 1, width do
        for y = 1, height do
            if cells[x][y] == 1 then
                lg.rectangle("fill",
                    offsetX + (x - 1) * cellSize,
                    offsetY + (y - 1) * cellSize,
                    cellSize, cellSize)
            end
        end
    end

    -- Draw dots
    lg.setColor(DOT_COLOR)
    for i = 1, #dots do
        local dot = dots[i]
        if not dot.collected then
            lg.circle("fill",
                offsetX + dot.x * cellSize - halfCell,
                offsetY + dot.y * cellSize - halfCell,
                dotRadius
            )
        end
    end

    -- Draw power pellets
    lg.setColor(PELLET_COLOR)
    for i = 1, #powerPellets do
        local pellet = powerPellets[i]
        if not pellet.collected then
            lg.circle("fill",
                offsetX + pellet.x * cellSize - halfCell,
                offsetY + pellet.y * cellSize - halfCell,
                pelletRadius
            )
        end
    end
end

return Maze
