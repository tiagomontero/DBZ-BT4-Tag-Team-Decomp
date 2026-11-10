-- Free look v1.8: personaje como pivote, orbita con el mouse.
--   - Mover el mouse: orbita la vista alrededor del personaje (yaw/pitch)
--   - Clic izquierdo: recentra en el personaje de inmediato
--   - Rueda del mouse: acerca / aleja la cámara (zoom)
--   - WASD / stick izquierdo: se mueve hacia donde mira la vista
--   - Sin mover el mouse por N segundos: vuelve suavemente a la cámara del juego
-- Los ataques siguen yendo al rival; el mouse solo cambia lo que se ve.

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
    version = "1.8",
    author = "BT4decomp",
    description = "Personaje como pivote. Orbita con el mouse, zoom con rueda, WASD sigue la vista.",
    settings = {
        { id = "enable", label = "Activar free look", type = "toggle", default = 1 },
        { id = "sens", label = "Sensibilidad mouse", type = "slider", min = 10, max = 500, step = 5, default = 150 },
        { id = "dist", label = "Distancia al personaje", type = "slider", min = 200, max = 1500, step = 25, default = 450 },
        { id = "height", label = "Altura sobre el personaje", type = "slider", min = 0, max = 700, step = 25, default = 220 },
        { id = "invert_y", label = "Invertir eje vertical", type = "toggle", default = 0 },
        { id = "pitch_min", label = "Pitch mínimo (deg)", type = "slider", min = -90, max = 0, step = 5, default = -75 },
        { id = "pitch_max", label = "Pitch máximo (deg)", type = "slider", min = 0, max = 90, step = 5, default = 60 },
        { id = "zoom_step", label = "Zoom por rueda", type = "slider", min = 5, max = 100, step = 5, default = 40 },
        { id = "recenter", label = "Recentrar automático tras (s)", type = "slider", min = 0, max = 10, step = 0.5, default = 3,
          tip = "0: nunca recentrar solo." },
    },
    on_frame = function(game)
        if not game.battle then
            sides = { {}, {} }
            bt3.set_free_look_yaw(0)
        end
    end,
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

        -- Elegir personaje activo (pivote): prioridad lado 0, si no lado 1
        local p = nil
        if game.f then
            p = game.f[0]
            if not p or not p.found then
                p = game.f[1]
            end
        end
        if not p or not p.found then
            bt3.set_free_look_yaw(0)
            return
        end

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

        -- Acumular desvío angular del mouse (respuesta inmediata)
        c.yaw = wrap((c.yaw or 0) + dx * sens)
        c.pitch = clamp((c.pitch or 0) - dy * sens * inv, pmin, pmax)

        -- Zoom con la rueda del mouse
        if scroll > 0 then
            c.dist = c.dist - zoom
        elseif scroll < 0 then
            c.dist = c.dist + zoom
        end
        c.dist = clamp(c.dist, dist_default, 1500)

        local now = game.time or 0
        if left then
            reset(c, dist_default)
        elseif dx ~= 0 or dy ~= 0 then
            c.lastMove = now
        end

        -- Auto-recentrado suave tras `auto` segundos sin movimiento
        if auto > 0 and c.lastMove and now - c.lastMove > auto then
            local k = 0.15
            c.yaw = c.yaw * (1 - k)
            c.pitch = c.pitch * (1 - k)
            c.dist = c.dist + (dist_default - c.dist) * k
        end

        -- Posición orbital alrededor del personaje (pivote)
        -- +Y es hacia abajo en este juego, así que elevar = restar en Y
        local cx = p.pos.x + c.dist * math.cos(c.pitch) * math.sin(c.yaw)
        local cy = p.pos.y - height
        local cz = p.pos.z + c.dist * math.cos(c.pitch) * math.cos(c.yaw)

        cam.pos.x = cx
        cam.pos.y = cy
        cam.pos.z = cz

        -- La cámara apunta siempre al personaje (centro del pivote)
        cam.target.x = p.pos.x
        cam.target.y = p.pos.y
        cam.target.z = p.pos.z

        -- Decirle a C el yaw para que WASD / el stick gire con la vista
        bt3.set_free_look_yaw(c.yaw)
    end,
}
