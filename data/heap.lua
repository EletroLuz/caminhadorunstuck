-- heap.lua
local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap:new()
    return setmetatable({nodes = {}}, MinHeap)
end

function MinHeap:insert(node)
    table.insert(self.nodes, node)
    self:_heapify_up(#self.nodes)
end

function MinHeap:pop()
    if #self.nodes == 0 then return nil end
    local root = self.nodes[1]
    self.nodes[1] = self.nodes[#self.nodes]
    table.remove(self.nodes)
    self:_heapify_down(1)
    return root
end

function MinHeap:empty()
    return #self.nodes == 0
end

function MinHeap:_heapify_up(index)
    local parent = math.floor(index / 2)
    if parent >= 1 and self.nodes[parent].f > self.nodes[index].f then
        self.nodes[parent], self.nodes[index] = self.nodes[index], self.nodes[parent]
        self:_heapify_up(parent)
    end
end

function MinHeap:_heapify_down(index)
    local left = 2 * index
    local right = 2 * index + 1
    local smallest = index

    if left <= #self.nodes and self.nodes[left].f < self.nodes[smallest].f then
        smallest = left
    end
    if right <= #self.nodes and self.nodes[right].f < self.nodes[smallest].f then
        smallest = right
    end
    if smallest ~= index then
        self.nodes[smallest], self.nodes[index] = self.nodes[index], self.nodes[smallest]
        self:_heapify_down(smallest)
    end
end

return MinHeap
