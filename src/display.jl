function Makie.backend_show(screen::Screen, io::IO, ::MIME"image/png", scene::Scene)
    Makie.push_screen!(scene, screen)
    taichi_draw(screen, scene)
    filename = io.name[7:(end - 1)]
    for task in screen.tasks
        apply!(screen, task)
    end
    screen.ti_window.window.save_image(filename)
    Base.empty!(screen.tasks)
    Base.empty!(screen.stack)
    return
end

function openurl(url::String)
    if Sys.isapple()
        tryrun(`open $url`) && return
    elseif Sys.iswindows()
        tryrun(`powershell.exe start $url`) && return
    elseif Sys.isunix()
        tryrun(`xdg-open $url`) && return
        tryrun(`gnome-open $url`) && return
    end
    tryrun(`python -mwebbrowser $(url)`) && return
    # our last hope
    tryrun(`python3 -mwebbrowser $(url)`) && return
    @warn("Can't find a way to open a browser, open $(url) manually!")
end

function Base.display(screen::Screen, scene::Scene = screen.scene)
    Makie.push_screen!(scene, screen)
    taichi_draw(screen, scene)
    for task in screen.tasks
        apply!(screen, task)
    end

    if visible(screen)
        screen.ti_window.window.show()
    else
        path = mktempdir()
        f = joinpath(path, "tmp.png")
        screen.ti_window.window.save_image(f)
        openurl("file:///" * f)
    end

    Base.empty!(screen.tasks)
    Base.empty!(screen.stack)
    return screen
end
