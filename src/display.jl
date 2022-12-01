function Makie.backend_show(screen::Screen, io::IO, ::MIME"image/png", scene::Scene)
    Makie.push_screen!(scene, screen)
    taichi_draw(screen, scene)
    filename = io.name[7:(end - 1)]
    screen.ti_window.window.save_image(filename)
    destroy!(screen)
    return
end
