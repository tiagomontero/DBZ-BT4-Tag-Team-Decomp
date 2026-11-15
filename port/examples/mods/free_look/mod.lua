return {
    name = "Free look",
    version = "5.0",
    author = "BT4decomp",
    description = "Cámara detrás del personaje. Mouse orbita, rueda zoom.",
    settings = {
        { id = "enable", label = "Activar free look", type = "toggle", default = 1 },
        { id = "sens", label = "Sensibilidad mouse", type = "slider", min = 5, max = 300, step = 5, default = 100 },
        { id = "dist", label = "Distancia al personaje", type = "slider", min = 200, max = 1500, step = 25, default = 450 },
        { id = "height", label = "Altura sobre el personaje", type = "slider", min = 0, max = 800, step = 25, default = 250 },
        { id = "zoom_step", label = "Zoom por rueda", type = "slider", min = 5, max = 100, step = 5, default = 50 },
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

        local sens = bt3.setting("sens") * 0.0005
        local m = game.mouse or {}
        local dx = m.dx or 0
        local dy = m.dy or 0
        local scroll = m.scroll or 0

        -- Estado persistente
        if not s_yaw then s_yaw = pyaw end
        if not s_pitch then s_pitch = -pi / 4 end
        if not s_dist then s_dist = bt3.setting("dist") end

        s_yaw = wrap((s_yaw or pyaw) + dx * sens)
        s_pitch = clamp((s_pitch or -pi / 4) - dy * sens, -pi / 2 + 0.1, pi / 2 - 0.1)

        local zstep = bt3.setting("zoom_step") or 50
        if scroll > 0 then s_dist = s.dist - zstep
        elseif scroll < 0 then s.dist = s.dist + zstep end
        s.dist = clamp(s.dist, 200, 1500)

        -- Cámara detrás del personaje
        local tyaw = wrap(pyaw + pi + s_yaw)
        local tpitch = s_pitch

        local cx = px + s.dist * math.cos(tpitch) * math.sin(tyaw)
        local cy = py - (bt3.setting("height") or 250)
        local cz = pz + s.dist * math.cos(tpitch) * math.cos(tyaw)

        -- Solo modificar posición y objetivo, NO tocar cam.rot
        cam.pos[1] = cx
        cam.pos[2] = cy
        cam.pos[3] = cz
        cam.target[1] = px
        cam.target[2] = py
        cam.target[3] = pz

        bt3.set_free_look_yaw(tyaw)
    end,
}
