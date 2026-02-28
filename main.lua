-- Minimal standalone example showing one PBR-textured sphere

local vertexFormat = {{"VertexPosition", "float", 3}, {"VertexNormal", "float", 3}, {"VertexTexCoord", "float", 2}}

local obj = require "obj"

local function flatten4(m)
    local out = {}
    for i = 1, 4 do
        for j = 1, 4 do
            out[#out + 1] = m[i][j]
        end
    end
    return out
end

local function ortho(l, r, b, t, n, f)
    local m = {
        {2/(r-l), 0, 0, -(r+l)/(r-l)},
        {0, 2/(t-b), 0, -(t+b)/(t-b)},
        {0,0,-2/(f-n), -(f+n)/(f-n)},
        {0,0,0,1}
    }
    return flatten4(m)
end

local function identity4()
    return {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}
end

local function identity3()
    return {1,0,0, 0,1,0, 0,0,1}
end

-- rotation state
local rotY = 0
local rotX = 0
local rotSpeedY = 0.6 -- radians/sec
local rotSpeedX = 0.3

local function rotationXYMatrix(rx, ry)
    local cx = math.cos(rx)
    local sx = math.sin(rx)
    local cy = math.cos(ry)
    local sy = math.sin(ry)
    -- Rotation X matrix (3x3)
    local Rx = {
        1, 0, 0,
        0, cx, -sx,
        0, sx, cx
    }
    -- Rotation Y matrix (3x3)
    local Ry = {
        cy, 0, sy,
        0, 1, 0,
        -sy, 0, cy
    }
    -- R = Ry * Rx (3x3 multiply)
    local R = {}
    for i = 0, 2 do
        for j = 0, 2 do
            local sum = 0
            for k = 0, 2 do
                sum = sum + Ry[i*3 + k + 1] * Rx[k*3 + j + 1]
            end
            R[i*3 + j + 1] = sum
        end
    end
    -- 4x4 row-major model matrix
    local model4 = {
        R[1], R[2], R[3], 0,
        R[4], R[5], R[6], 0,
        R[7], R[8], R[9], 0,
        0,    0,    0,    1
    }
    -- normal matrix is the upper-left 3x3 (for pure rotation inverse-transpose == R)
    local normal3 = {R[1], R[2], R[3], R[4], R[5], R[6], R[7], R[8], R[9]}
    return model4, normal3
end

function love.load()
    -- use the project's sphere vertex data for correct topology/normals
        -- enable depth testing to avoid Z-fighting artifacts
        love.graphics.setDepthMode("lequal", true)
        -- use strict "less" to avoid equal-depth race conditions on some drivers
        -- love.graphics.setDepthMode("less", true)
        -- enable back-face culling when available to avoid rendering reversed/duplicate triangles
        if love.graphics.setMeshCullMode then
            love.graphics.setMeshCullMode("back")
        end

        -- use the project's sphere vertex data for correct topology/normals
        mesh = love.graphics.newMesh(vertexFormat, obj.sphere, "triangles")

    -- load shader and textures (use assets from parent folder)
    shader = love.graphics.newShader("shader/texture.frag", "shader/texture.vert")
    local base = "assets/pbr/rusted_iron/"
    local albedo = love.graphics.newImage(base .. "albedo.png")
    local normal = love.graphics.newImage(base .. "normal.png")
    local metallic = love.graphics.newImage(base .. "metallic.png")
    local roughness = love.graphics.newImage(base .. "roughness.png")
    local ao = love.graphics.newImage(base .. "ao.png")

    shader:send("albedoMap", albedo)
    shader:send("normalMap", normal)
    shader:send("metallicMap", metallic)
    shader:send("roughnessMap", roughness)
    shader:send("aoMap", ao)

    -- (environment cubemap handled by project entry point; not required here)

    -- lights: four lights for clearer PBR highlights
    shader:send("lightPositions", {0, 0, 10,  5, 5, 10,  -5, 5, 10, 0, -5, 10})
    shader:send("lightColors", {400, 400, 400,  250, 250, 250,  250, 250, 250, 200, 200, 200})

    -- simple static camera position (world-space)
    shader:send("camPos", {0, 0, 3})

    -- prepare matrices
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local aspect = w / h
    projection = ortho(-2 * aspect, 2 * aspect, -2, 2, -10, 10)
    view = identity4()
    model = identity4()
    normalMat = identity3()

    mesh:setTexture(albedo)
end

function love.resize(w, h)
    local aspect = w / h
    projection = ortho(-2 * aspect, 2 * aspect, -2, 2, -10, 10)
end

function love.draw()
    love.graphics.clear(0.1, 0.1, 0.1)
    love.graphics.setShader(shader)
    shader:send("projectionMatrix", projection)
    shader:send("viewMatrix", identity4())
    shader:send("modelMatrix", model)
    shader:send("normalMatrix", normalMat)
    shader:send("camPos", {0, 0, 3})

    love.graphics.draw(mesh)
    love.graphics.setShader()
end

function love.update(dt)
    rotY = rotY + rotSpeedY * dt
    rotX = rotX + rotSpeedX * dt
    local m4, n3 = rotationXYMatrix(rotX, rotY)
    model = m4
    normalMat = n3
end
