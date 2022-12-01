export Screen

@enum RenderType SVG IMAGE PDF EPS

struct TaichiWindow
    window::Py
    width::Int
    height::Int
end

function TaichiWindow(title::AbstractString = "TaichiMakie", width = 512, height = 512)
    window = ti.ui.Window(title, (width, height), show_window = false)
    return TaichiWindow(window, width, height)
end

struct TaichiCanvas
    canvas::Py
end

function TaichiCanvas(ti_window::TaichiWindow)
    canvas = ti_window.window.get_canvas()
    return TaichiCanvas(canvas)
end

struct TaichiScene
    scene::Py
end

function TaichiScene()
    scene = ti.ui.Scene()
    return TaichiScene(scene)
end

struct ScreenConfig
end

mutable struct Screen <: Makie.MakieScreen
    ti_window::TaichiWindow
    ti_canvas::TaichiCanvas
    ti_scene::TaichiScene
    scene::Scene
    config::ScreenConfig
end

function Screen(scene::Scene; screen_config...)
    ti_window = TaichiWindow()
    ti_canvas = TaichiCanvas(window)
    ti_scene = TaichiScene()
    config = Makie.merge_screen_config(ScreenConfig, screen_config...)
    return Screen(ti_window, ti_canvas, ti_scene, scene, config)
end

width(screen::Screen) = screen.ti_window.width
height(screen::Screen) = screen.ti_window.height
Base.size(screen::Screen) = (width(screen), height(screen))

function destroy!(ti_window::TaichiWindow)
    ti_window.window.destroy()
end

function destroy!(screen::Screen)
    destroy!(screen.ti_window)
end

function empty!(screen::Screen)
    screen.ti_canvas.canvas.set_background_color((1.0, 1.0, 1.0))
end

function Base.isopen(screen::Screen)
    return pytruth(screen.window.running)
end

function Base.show(io::IO, ::MIME"text/plain", screen::Screen)
    println(io, "TaichiMakie.Screen")
end

function FileIO.save(filename::AbstractString, screen::Screen)
    screen.window.save_image(filename)
end

function Screen(scene::Scene, config::ScreenConfig, io_or_path::Union{Nothing, String, IO},
                typ::Union{MIME, Symbol, RenderType})
    w, h = round.(Int, size(scene))
    ti_window = TaichiWindow("TaichiMakie", w, h)
    ti_canvas = TaichiCanvas(ti_window)
    ti_scene = TaichiScene()

    return Screen(ti_window, ti_canvas, ti_scene, scene, config)
end

const LAST_INLINE = Ref(true)

function activate!(; inline = LAST_INLINE[], screen_config...)
    Makie.inline!(inline)
    LAST_INLINE[] = inline
    Makie.CURRENT_DEFAULT_THEME[:TaichiMakie] = Makie.Attributes()
    Makie.set_screen_config!(TaichiMakie, screen_config)
    Makie.set_active_backend!(TaichiMakie)
    ti.init(arch = ti.vulkan)
end

function Makie.colorbuffer(screen::Screen)
    empty!(screen)
    taichi_draw(screen, screen.scene)
end
