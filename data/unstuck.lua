-- Importa a MinHeap do arquivo heap.lua
local MinHeap = require("data.heap")

-- Definição do estado de pathfinding
local pathfinding_state = {
    open_list = MinHeap:new(),
    closed_list = {},
    iterations = 0,
    max_iterations = 10000,
    path_complete = true,
    current_path = {}
}

-- Função para calcular a distância Euclidiana entre dois pontos
local function euclidean_distance(pos1, pos2)
    return math.sqrt((pos1:x() - pos2:x())^2 + (pos1:y() - pos2:y())^2 + (pos1:z() - pos2:z())^2)
end

-- Função para converter uma posição para string
local function pos_to_string(pos)
    return string.format("(%f, %f, %f)", pos:x(), pos:y(), pos:z())
end

-- Função para obter os vizinhos de um ponto
local function get_neighbors(pos)
    local neighbors = {}
    local directions = {
        vec3:new(1, 0, 0), vec3:new(-1, 0, 0),
        vec3:new(0, 1, 0), vec3:new(0, -1, 0),
        vec3:new(0, 0, 1), vec3:new(0, 0, -1)
    }

    for _, dir in ipairs(directions) do
        local neighbor = vec3:new(pos:x() + dir:x(), pos:y() + dir:y(), pos:z() + dir:z())
        -- Ajuste a altura do vizinho para uma posição válida
        local neighbor_adjusted = utility.set_height_of_valid_position(neighbor)
        table.insert(neighbors, neighbor_adjusted)
    end
    return neighbors
end

-- Função para verificar se um ponto está em uma lista
local function is_in_list(list, pos)
    for _, node in ipairs(list) do
        if node.pos:x() == pos:x() and node.pos:y() == pos:y() and node.pos:z() == pos:z() then
            return true
        end
    end
    return false
end

-- Função para obter um nó de uma lista baseado na posição
local function get_node_from_list(list, pos)
    for _, node in ipairs(list) do
        if node.pos:x() == pos:x() and node.pos:y() == pos:y() and node.pos:z() == pos:z() then
            return node
        end
    end
    return nil
end

-- Função para verificar se uma posição está dentro dos limites da área de busca
local function is_within_bounds(pos, center, radius)
    return euclidean_distance(pos, center) <= radius
end

-- Função principal para continuar o pathfinding
local function continue_pathfinding(goal_position, max_distance)
    local start_time = os.clock()
    local time_limit = 0.02 -- Tempo máximo por frame
    local search_radius = 150 -- Ajuste conforme necessário

    while os.clock() - start_time < time_limit and not pathfinding_state.path_complete do
        if pathfinding_state.open_list:empty() or pathfinding_state.iterations >= pathfinding_state.max_iterations then
            pathfinding_state.path_complete = true
            break
        end

        pathfinding_state.iterations = pathfinding_state.iterations + 1
        local current = pathfinding_state.open_list:pop()
        table.insert(pathfinding_state.closed_list, current)

        if euclidean_distance(current.pos, goal_position) < 1 or #pathfinding_state.current_path >= max_distance then
            while current.parent do
                table.insert(pathfinding_state.current_path, 1, current.pos)
                current = current.parent
            end

            local end_time = os.clock()
            local work_time = end_time - pathfinding_state.start_time
            console.print("Path solved, time: " .. work_time)
            pathfinding_state.path_complete = true
            break
        end

        local neighbors = get_neighbors(current.pos)
        for _, neighbor in ipairs(neighbors) do
            if is_within_bounds(neighbor, current.pos, search_radius) and not is_in_list(pathfinding_state.closed_list, neighbor) and utility.is_point_walkeable(neighbor) then
                local g = current.g + euclidean_distance(current.pos, neighbor)
                local h = euclidean_distance(neighbor, goal_position)
                local f = g + h
                local neighbor_node = {pos = neighbor, g = g, h = h, f = f, parent = current}

                if not is_in_list(pathfinding_state.open_list.nodes, neighbor) then
                    pathfinding_state.open_list:insert(neighbor_node)
                else
                    local existing = get_node_from_list(pathfinding_state.open_list.nodes, neighbor)
                    if existing and g < existing.g then
                        existing.g = g
                        existing.parent = current
                    end
                end
            end
        end
    end
end

-- Função para iniciar o pathfinding
local function initiate_pathfinding(player_pos, goal_position, max_distance)
    pathfinding_state.open_list = MinHeap:new()
    pathfinding_state.open_list:insert({pos = player_pos, g = 0, h = euclidean_distance(player_pos, goal_position), f = euclidean_distance(player_pos, goal_position)})
    pathfinding_state.closed_list = {}
    pathfinding_state.iterations = 0
    pathfinding_state.path_complete = false
    pathfinding_state.current_path = {}
    pathfinding_state.start_time = os.clock()
    console.print("Initiate pathfinding at " .. os.clock())
end

local previous_point = nil
local stuck_timer = 0
local stuck_threshold = 3 -- Segundos
local wait_time_before_recalculate = 5 -- Segundos
local last_recalculation_time = os.clock()

-- Função para mover o jogador ao longo do caminho
local function move_along_path()
    if #pathfinding_state.current_path > 0 then
        local next_point = pathfinding_state.current_path[1]
        local player_pos = get_player_position()
        local distance_to_next_point = euclidean_distance(player_pos, next_point)

        -- Verifica se o próximo ponto é acessível
        if not utility.is_point_walkeable(next_point) then
            console.print("Next point is not walkable, recalculating path")
            console.print("Next point: " .. pos_to_string(next_point))
            console.print("Player position: " .. pos_to_string(player_pos))
            initiate_pathfinding(player_pos, goal_position, max_distance)
            return
        end

        -- Verificação de ciclos
        if previous_point and euclidean_distance(player_pos, previous_point) < 1 then
            if os.clock() - last_recalculation_time > wait_time_before_recalculate then
                console.print("Detected potential loop, recalculating path")
                initiate_pathfinding(player_pos, goal_position, max_distance)
                last_recalculation_time = os.clock()
                return
            end
        end

        -- Ajuste a tolerância de distância
        local tolerance = 5

        if distance_to_next_point < tolerance then
            previous_point = table.remove(pathfinding_state.current_path, 1)
            stuck_timer = 0
        else
            pathfinder.request_move(next_point)
            stuck_timer = stuck_timer + 1
            if stuck_timer > stuck_threshold then
                console.print("Detected player is stuck, recalculating path")
                initiate_pathfinding(player_pos, goal_position, max_distance)
                stuck_timer = 0
                last_recalculation_time = os.clock()
            end
        end
    end
end

-- Função chamada a cada renderização
on_render(function()
    if not pathfinding_state.path_complete then
        continue_pathfinding(current_waypoint, max_distance)
    end

    -- Renderiza o caminho encontrado
    for i, pos in ipairs(pathfinding_state.current_path) do
        graphics.circle_3d(pos, 0.3, color_gold(255), 2.0)
    end

    -- Move o jogador ao longo do caminho
    move_along_path()
end)

console.print(">> Pathfinding Script Loaded <<")
