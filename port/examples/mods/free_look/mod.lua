-- Free look v3.0 - Camara detras del personaje, orbita con el mouse
-- Solo usa cam.pos y cam.target (sin tocar cam.rot para evitar crasheos)

local pi = math.pi
local function clamp(v, a, b) return v < a and a or v > b and b or v end
local function wrap(a)
    while a > pi do a = a - 2 * pi end
    while a < -pi do a = a + 2 * pi end
    return a
end

local state = {}

return {
    name = "Free look",
    version = "3.0",
    author = "BT4decomp",
    description = "Camara detras del personaje. Mouse orbita, rueda zoom, camara sigue al personaje.",
    settings = {
        { id = "enable", label = "Activar free look", type = "toggle", default = 1 },
        { id = "sens", label = "Sensibilidad mouse", type = "slider", min = 10, max = 200, step = 5, default = 80 },
        { id = "dist", label = "Distancia al personaje", type = "slider", min = 200, max = 1200, step = 25, default = 450 },
        { id = "height", label = "Altura sobre el personaje", type = "slider", min = 0, max = 600, step = 25, default = 200 },
        { id = "zoom_step", label = "Zoom por rueda", type = "slider", min = 10, max = 100, step = 5, default = 40 },
    },
    on_camera = function(cam, game)
        if not game.battle or not bt3.setting("enable") then
            bt3.set_free_look_yaw(0)
            return
        end
        if cam.cut then
            bt3.set_free_look_yaw(0)
            return
        end

        local s = state[cam.side]
        if not s then s = {} state[cam.side] = s end
        if s.dist == nil then s.dist = bt3.setting("dist") end

        local p = nil
        if game.f then
            p = game.f[0]
            if not p or not p.found then p = game.f[1] end
        end
        if not p or not p.found then
            bt3.set_free_look_yaw(0)
            return
        end

        local px, py, pz = p.pos[1], p.pos[2], p.pos[3]
        local pyaw = p.yaw or 0

        local sens = bt3.setting("sens") * 0.0004
        local m = game.mouse or {}
        local dx = m.dx or 0
        local dy = m.dy or 0
        local scroll = m.scroll or 0

        -- Acumular offset del mouse
        s.yaw = wrap((s.yaw or 0) + dx * sens)
        s.pitch = clamp((s.pitch or -pi / 4) - dy * sens, -pi / 2 + 0.1, pi / 2 - 0.1)

        -- Zoom con rueda
        local zstep = bt3.setting("zoom_step") or 40
        if scroll > 0 then s.dist = s.dist - zstep
        elseif scroll < 0 then s.dist = s.dist + zstep end
        s.dist = clamp(s.dist, 200, 1200)

        -- Camara DETRAS del personaje
        local tyaw = wrap(pyaw + pi + s.yaw)
        local tpitch = s.pitch

        local cx = px + s.dist * math.cos(tpitch) * math.sin(tyaw)
        local cy = py - (bt3.setting("height") or 200)
        local cz = pz + s.dist * math.cos(tpitch) * math.cos(tyaw)

        cam.pos[1] = cx
        cam.pos[2] = cy
        cam.pos[3] = cz
        cam.target[1] = px
        cam.target[2] = py
        cam.target[3] = pz

        -- Solo el yaw para WASD, NO tocamos cam.rot para evitar crasheos
        bt3.set_free_look_yaw(tyaw)
    end,
}
