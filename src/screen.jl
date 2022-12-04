export Screen

struct TaichiWindow
    window::Py
    visible::Bool
    width::Int
    height::Int
end

function TaichiWindow(title::AbstractString = "TaichiMakie", width = 512, height = 512;
                      show_window = false)
    window = ti.ui.Window(title, (width, height), show_window = show_window)
    return TaichiWindow(window, show_window, width, height)
end

struct ScreenConfig
    visible::Bool
end

ScreenConfig() = ScreenConfig(false)

struct GGUITask
    scene::Scene
    type::Symbol
    vertices::Vector{Vec3f}
    indices::Vector{Vec3i}
    colors::Vector{Vec3f}
    attributes::Dict{Symbol, Any}
end

function GGUITask(scene, type, vertices, indices, colors)
    return GGUITask(scene, type, vertices, indices, colors, Dict{Symbol, Any}())
end

mutable struct Screen <: Makie.MakieScreen
    ti_window::TaichiWindow
    ti_canvas::Py
    scene::Scene
    config::ScreenConfig
    translate::Mat3f
    stack::Vector{Mat3f}
    tasks::Vector{GGUITask}
end

function apply!(screen::Screen, task::GGUITask)
    scale_factor = 1 / width(screen)

    if task.type != :mesh
        vertices = [task.vertices[i][j] for i in eachindex(task.vertices), j in 1:2]
        ti_vertices = ti.Vector.field(2, ti.f32, length(task.vertices))
        ti_vertices.from_numpy(np.array(vertices))
    end

    colors = [task.colors[i][j]
              for i in eachindex(task.colors), j in 1:3]
    ti_colors = ti.Vector.field(3, ti.f32, length(task.colors))
    ti_colors.from_numpy(np.array(colors))

    if task.type == :line
        indices = [task.indices[i][j] for i in eachindex(task.indices), j in 1:2]
        ti_indices = ti.Vector.field(2, ti.i32, length(task.indices))
        ti_indices.from_numpy(np.array(indices))
        screen.ti_canvas.lines(vertices = ti_vertices,
                               width = get(task.attributes, :linewidth, 0.0) * scale_factor,
                               indices = ti_indices,
                               per_vertex_color = ti_colors)
    elseif task.type == :triangle
        indices = [task.indices[i][j] for i in eachindex(task.indices), j in 1:3]
        ti_indices = ti.Vector.field(3, ti.i32, length(task.indices))
        ti_indices.from_numpy(np.array(indices))
        screen.ti_canvas.triangles(vertices = ti_vertices, indices = ti_indices,
                                   per_vertex_color = ti_colors)
    elseif task.type == :circle
        screen.ti_canvas.circles(centers = ti_vertices,
                                 radius = get(task.attributes, :markersize, 0.0) *
                                          scale_factor,
                                 per_vertex_color = ti_colors)
    elseif task.type == :mesh
        # TODO: correctly render meshes
        ambient = to_taichi_color(get(task.attributes, :ambient,
                                      Makie.get_ambient_light(task.scene).color[]))
        pointlight = Makie.get_point_light(task.scene)
        lightpos = get(task.attributes, :lightpos, pointlight.position[])

        pixel_space = task.scene.camera.pixel_space[]
        projected_vertices = [pixel_space *
                              to_ndim(Vec4f, task.vertices[i], 0.0)
                              for i in eachindex(task.vertices)]
        vertices = [projected_vertices[i][j]
                    for i in eachindex(projected_vertices), j in 1:3]
        # vertices = [task.vertices[i][j] for i in eachindex(task.vertices), j in 1:3]
        ti_vertices = ti.Vector.field(3, ti.f32, length(task.vertices))
        ti_vertices.from_numpy(np.array(vertices))

        camera = ti.ui.Camera()
        camera.position(lightpos...)
        camctl = task.scene.camera_controls

        if camctl isa Camera3D
            @show camctl.lookat
            camera.lookat(camctl.lookat[]...)
            camera.up(camctl.upvector[]...)
        end

        scene = ti.ui.Scene()
        scene.set_camera(camera)
        scene.ambient_light(ambient)
        scene.point_light(lightpos, (1.0, 1.0, 1.0))
        scene.mesh(ti_vertices, per_vertex_color = ti_colors)
        screen.ti_canvas.scene(scene)
    end
end

function Screen(scene::Scene, config::ScreenConfig, ti_window)
    ti_canvas = ti_window.window.get_canvas()
    translate = Mat3f([1/ti_window.width 0 0
                       0 1/ti_window.height 0
                       0 0 0])
    stack = Mat3f[]
    tasks = GGUITask[]

    return Screen(ti_window, ti_canvas, scene, config, translate, stack, tasks)
end

function merge_screen_config(::Type{Config}, screen_config_kw) where {Config}
    @show screen_config_kw
    kw_nt = screen_config_kw
    arguments = map(fieldnames(Config)) do name
        get(kw_nt, name, nothing)
    end
    return Config(arguments...)
end

function Screen(scene::Scene; screen_config...)
    config = merge_screen_config(ScreenConfig, screen_config)
    w, h = round.(Int, size(scene))
    ti_window = TaichiWindow("TaichiMakie", w, h; show_window = config.visible)
    return Screen(scene, config, ti_window)
end

function Screen(scene::Scene, config::ScreenConfig, io_or_path::Union{Nothing, String, IO},
                typ::Union{MIME, Symbol})
    w, h = round.(Int, size(scene))
    ti_window = TaichiWindow("TaichiMakie", w, h; show_window = config.visible)
    return Screen(scene, config, ti_window)
end

visible(screen::Screen) = screen.ti_window.visible
width(screen::Screen) = screen.ti_window.width
height(screen::Screen) = screen.ti_window.height
Base.size(screen::Screen) = (width(screen), height(screen))

function Base.show(io::IO, ::MIME"text/plain", screen::Screen)
    println(io, "TaichiMakie.Screen")
end

function save_ctx!(screen::Screen)
    push!(screen.stack, screen.translate)
end

function restore_ctx!(screen::Screen)
    screen.translate = pop!(screen.stack)
end

function destroy!(ti_window::TaichiWindow)
    ti_window.window.destroy()
end

function destroy!(screen::Screen)
    destroy!(screen.ti_window)
end

function Base.empty!(screen::Screen)
    screen.ti_canvas.canvas.set_background_color((1.0, 1.0, 1.0))
end

function Base.isopen(screen::Screen)
    return pytruth(screen.window.running)
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
    buf = PyArray(screen.ti_window.window.get_image_buffer_as_numpy())
    # w, h = size(screen)
    # [ARGB32(RGBAf(buf[i, j, 1], buf[i, j, 2], buf[i, j, 3], buf[i, j, 4]))
    #  for i in 1:w, j in 1:h]
end
