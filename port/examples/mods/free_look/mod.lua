-- Free look v2.0: cámara siempre DETRÁS del personaje, sigue cuando se mueve.
--   - Mover el mouse: orbita alrededor del personaje (yaw/pitch)
--   - Clic izquierdo: recentra directamente detrás del personaje
--   - Rueda del mouse: acerca / aleja (zoom)
--   - WASD / stick: el personaje se mueve, la cámara lo sigue
--   - Sin mouse por N segundos: vuelve suavemente a cámara normal
-- Los ataques siguen yendo al rival; el mouse solo cambia la vista.

local pi = math.pi
local function clamp(v, a, b) return v < a and a or v > b and b or v end
local function wrap(a)
    while a > pi do a = a - 2 * pi end
    while a < -pi do a = a + 2 * pi end
    return a
end

local sides = { {}, {} }

local function reset(c, dist_default)
    c.yaw = 0
    c.pitch = 0
    c.dist = dist_default
    c.lastMove = nil
end

return {
    name = "Free look",
    version = "2.0",
    author = "BT4decomp",
    description = "Cámara siempre detrás del personaje. Orbita con el mouse, sigue al personaje.",
    settings = {
        { id = "enable", label = "Activar free look", type = "toggle", default = 1 },
        { id = "sens", label = "Sensibilidad mouse", type = "slider", min = 10, max = 500, step = 5, default = 150 },
        { id = "dist", label = "Distancia al personaje", type = "slider", min = 200, max = 1500, step = 25, default = 500 },
        { id = "height", label = "Altura sobre el personaje", type = "slider", min = 0, max = 700, step = 25, default = 220 },
        { id = "invert_y", label = "Invertir eje vertical", type = "toggle", default = 0 },
        { id = "pitch_min", label = "Pitch mínimo (deg)", type = "slider", min = -90, max = 0, step = 5, default = -75 },
        { id = "pitch_max", label = "Pitch máximo (deg)", type = "slider", min = 0, max = 90, step = 5, default = 60 },
        { id = "zoom_step", label = "Zoom por rueda", type = "slider", min = 5, max = 100, step = 5, default = 40 },
        { id = "recenter", label = "Recentrar automático tras (s)", type = "slider", min = 0, max = 10, step = 0.5, default = 3, tip = "0: nunca" },
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

        local c = sides[cam.side]
        if not c then c = {} sides[cam.side] = c end
        if c.dist == nil then c.dist = bt3.setting("dist") end

        -- Elegir personaje activo (pivote): lado 0, si no lado 1
        local p = nil
        if game.f then
            p = game.f[0]
            if not p or not p.found then p = game.f[1] end
        end
        if not p or not p.found then
            bt3.set_free_look_yaw(0)
            return
        end

        -- p.pos es tabla {1=x, 2=y, 3=z}; p.yaw es número
        local px, py, pz = p.pos[1], p.pos[2], p.pos[3]
        local pyaw = p.yaw or 0

        local sens = bt3.setting("sens") * 0.0005
        local inv = bt3.setting("invert_y") and -1 or 1
        local pmin = bt3.setting("pitch_min") * pi / 180
        local pmax = bt3.setting("pitch_max") * pi / 180
        local auto = bt3.setting("recenter")
        local zoom = bt3.setting("zoom_step")
        local height = bt3.setting("height")
        local dist_default = bt3.setting("dist")

        local m = game.mouse or {}
        local dx = m.dx or 0
        local dy = m.dy or 0
        local scroll = m.scroll or 0
        local left = m.left or false

        -- Acumular offset del mouse
        c.yaw = wrap((c.yaw or 0) + dx * sens)
        c.pitch = clamp((c.pitch or 0) - dy * sens * inv, pmin, pmax)

        -- Zoom con rueda
        if scroll > 0 then c.dist = c.dist - zoom
        elseif scroll < 0 then c.dist = c.dist + zoom end
        c.dist = clamp(c.dist, dist_default, 1500)

        local now = game.time or 0
        if left then
            reset(c, dist_default)
        elseif dx ~= 0 or dy ~= 0 then
            c.lastMove = now
        end

        -- Auto-recentrado suave
        if auto > 0 and c.lastMove and now - c.lastMove > auto then
            local k = 0.15
            c.yaw = c.yaw * (1 - k)
            c.pitch = c.pitch * (1 - k)
            c.dist = c.dist + (dist_default - c.dist) * k
        end

        -- Cámara DETRÁS del personaje: p.yaw + pi = 180° (detrás)
        -- c.yaw = offset extra del mouse para orbita
        local total_yaw = wrap(pyaw + pi + c.yaw)
        local total_pitch = c.pitch

        -- Posición orbital alrededor del personaje (pivote = centro del personaje)
        -- +Y es hacia abajo en este juego, elevar = restar en Y
        local cx = px + c.dist * math.cos(total_pitch) * math.sin(total_yaw)
        local cy = py - height
        local cz = pz + c.dist * math.cos(total_pitch) * math.cos(total_yaw)

        -- Modificar cámara en su lugar (la tabla cam se pasa por referencia)
        cam.pos[1] = cx
        cam.pos[2] = cy
        cam.pos[3] = cz
        cam.target[1] = px
        cam.target[2] = py
        cam.target[3] = pz
        cam.rot[1] = total_pitch
        cam.rot[2] = total_yaw
        cam.rot[3] = 0

        -- Decirle a C el yaw para que WASD / el stick gire con la vista
        bt3.set_free_look_yaw(total_yaw)
    end,
}
