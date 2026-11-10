-- Free look estilo tercera persona: el personaje es el pivote (centro).
-- El mouse orbita alrededor del personaje: a los lados gira la vista (yaw),
-- arriba/abajo inclina la cámara (pitch, limitado para no dar vuelta).
-- El personaje avanza hacia donde mira la cámara (W usa el free-look yaw).
-- La rueda del mouse hace zoom (acerca / aleja).
--
--   - distancia: qué tan lejos está la cámara del personaje
--   - altura: qué tan alta está la cámara sobre el personaje
--   - pitch: ángulo vertical (desde arriba, -90 = cenit, 0 = horizontal)
--   - zoom_step: cuánto se acerca / aleja por paso de rueda

local pi = math.pi
local function clamp(v, a, b) return v < a and a or v > b and b or v end
local function wrap(a)
    while a > pi do a = a - 2 * pi end
    while a < -pi do a = a + 2 * pi end
    return a
end

return {
    name = "Free look: personaje pivote",
    version = "1.4",
    author = "BT4decomp",
    description = "El personaje es el pivote. El mouse orbita alrededor de él; la rueda hace zoom. El personaje avanza hacia donde mira la cámara (W).",
    settings = {
        { id = "enable", label = "Activar free look", type = "toggle", default = 1 },
        { id = "sens", label = "Sensibilidad mouse", type = "slider", min = 10, max = 300, step = 5, default = 100 },
        { id = "dist", label = "Distancia al personaje", type = "slider", min = 200, max = 1500, step = 25, default = 450 },
        { id = "height", label = "Altura sobre el personaje", type = "slider", min = 50, max = 700, step = 25, default = 220 },
        { id = "pitch", label = "Ángulo vertical (desde arriba)", type = "slider", min = -80, max = -15, step = 5, default = -30 },
        { id = "zoom_step", label = "Zoom por rueda", type = "slider", min = 10, max = 100, step = 5, default = 40 },
    },
    on_camera = function(cam, game)
        if not game.battle or not bt3.setting("enable") then
            bt3.set_free_look_yaw(0)
            return
        end

        -- Elegir personaje activo: prioridad al lado 0, si no el lado 1
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

        -- Inicializar estado persistente de esta sesión
        if not self.ang then
            self.ang = {
                yaw = p.yaw,            -- empezar mirando hacia donde mira el personaje
                pitch = bt3.setting("pitch") * pi / 180,
            }
            self.dist = bt3.setting("dist")
        end

        local m = game.mouse or {}
        local dx = m.dx or 0
        local dy = m.dy or 0
        local scroll = m.scroll or 0

        local sens = bt3.setting("sens") * 0.0005
        self.ang.yaw = wrap(self.ang.yaw + dx * sens)
        self.ang.pitch = clamp(self.ang.pitch - dy * sens, -pi / 2 + 0.05, -0.15)

        -- Zoom con la rueda del mouse
        local zoom = bt3.setting("zoom_step")
        if scroll > 0 then
            self.dist = self.dist - zoom   -- rueda hacia arriba: alejar
        elseif scroll < 0 then
            self.dist = self.dist + zoom   -- rueda hacia abajo: acercar
        end
        self.dist = clamp(self.dist, bt3.setting("dist"), 1500)

        local height = bt3.setting("height")

        -- Posición de la cámara: orbita alrededor del personaje (pivote)
        -- +Y es hacia abajo en este juego, así que elevar = restar en Y
        local cx = p.pos.x + self.dist * math.cos(self.ang.pitch) * math.sin(self.ang.yaw)
        local cy = p.pos.y - height
        local cz = p.pos.z + self.dist * math.cos(self.ang.pitch) * math.cos(self.ang.yaw)

        cam.pos.x = cx
        cam.pos.y = cy
        cam.pos.z = cz

        -- La cámara apunta siempre al personaje (centro del pivote)
        cam.target.x = p.pos.x
        cam.target.y = p.pos.y
        cam.target.z = p.pos.z

        -- Decirle a C hacia dónde mira la cámara: el personaje usa este yaw
        -- para moverse con W / stick (apply_free_look_to_stick en gs_input.c)
        bt3.set_free_look_yaw(self.ang.yaw)
    end,
}
