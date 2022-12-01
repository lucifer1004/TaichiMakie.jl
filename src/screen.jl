export Screen

@enum GGUITaskType CircleTask LineTask TriangleTask

struct TaichiWindow
    window::Py
    width::Int
    height::Int
end

function TaichiWindow(title::AbstractString = "TaichiMakie", width = 512, height = 512)
    window = ti.ui.Window(title, (width, height), show_window = false)
    return TaichiWindow(window, width, height)
end

struct ScreenConfig
end

struct GGUITask
    type::GGUITaskType
    vertices::Vector{NTuple{3, Float32}}
    linewidth::Float32
    markersize::Float32
    indices::Vector{NTuple{3, Int32}}
    colors::Vector{NTuple{3, Float32}}
    fields::Vector{TaichiField}
end

function GGUITask(type, vertices, linewidth, markersize, indices, colors)
    return GGUITask(type, vertices, linewidth, markersize, indices, colors, TaichiField[])
end

struct Screen <: Makie.MakieScreen
    ti_window::TaichiWindow
    ti_canvas::Py
    ti_scene::Py
    scene::Scene
    config::ScreenConfig
    tasks::Vector{GGUITask}
end

function apply!(screen::Screen, task::GGUITask)
    vertices = [task.vertices[i][j] for i in eachindex(task.vertices), j in 1:2]
    ti_vertices = TaichiField(2, ti.f32, (length(task.vertices),))
    push!(ti_vertices, vertices)
    push!(task.fields, ti_vertices)

    colors = [task.colors[i][j]
              for i in eachindex(task.colors), j in 1:3]
    ti_colors = TaichiField(3, ti.f32, (length(colors),))
    push!(ti_colors, colors)
    push!(task.fields, ti_colors)

    if task.type == LineTask
        indices = [task.indices[i][j] for i in eachindex(task.indices), j in 1:2]
        ti_indices = TaichiField(2, ti.i32, (length(task.indices),))
        push!(ti_indices, indices)
        push!(task.fields, ti_indices)

        screen.ti_canvas.lines(vertices = ti_vertices.field, width = task.linewidth,
                               indices = ti_indices.field,
                               per_vertex_color = ti_colors.field)
    elseif task.type == TriangleTask
        indices = [task.indices[i][j] for i in eachindex(task.indices), j in 1:3]
        ti_indices = TaichiField(3, ti.i32, (length(task.indices),))
        push!(ti_indices, indices)
        push!(task.fields, ti_indices)

        screen.ti_canvas.triangles(vertices = ti_vertices.field, indices = ti_indices.field,
                                   per_vertex_color = ti_colors.field)
    elseif task.type == CircleTask
        screen.ti_canvas.circles(centers = ti_vertices.field, radius = task.markersize,
                                 per_vertex_color = ti_colors.field)
    end
end

function Screen(scene::Scene; screen_config...)
    ti_window = TaichiWindow()
    ti_canvas = ti_window.window.get_canvas()
    ti_scene = ti.ui.Scene()
    config = Makie.merge_screen_config(ScreenConfig, screen_config...)
    tasks = GGUITask[]
    return Screen(ti_window, ti_canvas, ti_scene, scene, config, tasks)
end

width(screen::Screen) = screen.ti_window.width
height(screen::Screen) = screen.ti_window.height
Base.size(screen::Screen) = (width(screen), height(screen))

function destroy!(ti_window::TaichiWindow)
    ti_window.window.destroy()
end

function destroy!(screen::Screen)
    for task in screen.tasks
        for field in task.fields
            destroy!(field)
        end
    end
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

function Screen(scene::Scene, config::ScreenConfig, io_or_path::Union{Nothing, String, IO},
                typ::Union{MIME, Symbol})
    w, h = round.(Int, size(scene))
    ti_window = TaichiWindow("TaichiMakie", w, h)
    ti_canvas = ti_window.window.get_canvas()
    ti_scene = ti.ui.Scene()
    tasks = GGUITask[]

    return Screen(ti_window, ti_canvas, ti_scene, scene, config, tasks)
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
