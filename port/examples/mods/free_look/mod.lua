-- Free look estilo GTA V: la cámara orbita siempre alrededor del centro del
-- personaje activo, vista desde arriba, con distancia y altura ajustables.
-- El mouse gira alrededor del personaje; WASD / stick sigue la vista.
--   - distancia: qué tan lejos está la cámara del personaje
--   - altura: qué tan alta está la cámara sobre el personaje
--   - pitch: ángulo vertical (desde arriba, -90 = cenit, 0 = horizontal)

local pi = math.pi
local function clamp(v, a, b) return v < a and a or v > b and b or v end
local function wrap(a)
    while a > pi do a = a - 2 * pi end
    while a < -pi do a = a + 2 * pi end
    return a
end

return {
    name = "Free look GTA V",
    version = "1.2",
    author = "BT4decomp",
    description = "Cámara centrada en el personaje visto desde arriba, estilo GTA V. El mouse orbita alrededor del cuerpo; los sliders ajustan distancia y altura.",
    settings = {
        { id = "enable", label = "Activar cámara GTA V", type = "toggle", default = 1 },
        { id = "sens", label = "Sensibilidad mouse", type = "slider", min = 10, max = 300, step = 5, default = 100 },
        { id = "dist", label = "Distancia al personaje", type = "slider", min = 300, max = 1800, step = 50, default = 750 },
        { id = "height", label = "Altura sobre el personaje", type = "slider", min = 100, max = 900, step = 50, default = 400 },
        { id = "pitch", label = "Ángulo vertical (desde arriba)", type = "slider", min = -80, max = -15, step = 5, default = -45 },
    },
    on_camera = function(cam, game)
        if not game.battle or not bt3.setting("enable") then
            bt3.set_free_look_yaw(0)
            return
        end

        -- Elegir personaje activo: prioridad al lado 0, si no existe el lado 1
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

        if not self.ang then self.ang = { yaw = 0, pitch = bt3.setting("pitch") * pi / 180 } end

        local m = game.mouse or {}
        local dx = m.dx or 0
        local dy = m.dy or 0

        local sens = bt3.setting("sens") * 0.0005
        self.ang.yaw = wrap(self.ang.yaw + dx * sens)
        self.ang.pitch = clamp(self.ang.pitch - dy * sens, -pi / 2 + 0.05, -0.15)

        local dist = bt3.setting("dist")
        local height = bt3.setting("height")

        -- En este juego +Y es hacia abajo, así que para elevar la cámara restamos en Y
        local cx = p.pos.x + dist * math.cos(self.ang.pitch) * math.sin(self.ang.yaw)
        local cy = p.pos.y - height
        local cz = p.pos.z + dist * math.cos(self.ang.pitch) * math.cos(self.ang.yaw)

        cam.pos.x = cx
        cam.pos.y = cy
        cam.pos.z = cz

        cam.target.x = p.pos.x
        cam.target.y = p.pos.y
        cam.target.z = p.pos.z

        bt3.set_free_look_yaw(self.ang.yaw)
    end,
}
