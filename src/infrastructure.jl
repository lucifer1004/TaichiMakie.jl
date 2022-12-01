function taichi_draw(screen::Screen, scene::Scene)
    draw_background(screen, scene)

    allplots = get_all_plots(scene)
    zvals = Makie.zvalue2d.(allplots)
    permute!(allplots, sortperm(zvals))

    last_scene = scene
    for p in allplots
        to_value(get(p, :visible, true)) || continue
        # only prepare for scene when it changes
        # this should reduce the number of unnecessary clipping masks etc.
        pparent = p.parent::Scene
        pparent.visible[] || continue
        if pparent != last_scene
            prepare_for_scene(screen, pparent)
            last_scene = pparent
        end

        draw_plot(pparent, screen, p)
    end

    return
end

function get_all_plots(scene, plots = AbstractPlot[])
    append!(plots, scene.plots)
    for c in scene.children
        get_all_plots(c, plots)
    end
    plots
end

function prepare_for_scene(screen::Screen, scene::Scene)
end

function draw_background(screen::Screen, scene::Scene)
    if scene.clear[]
        bg = scene.backgroundcolor[]
        r = pixelarea(scene)[]
        color = (red(bg), green(bg), blue(bg))
        draw_rectangle(screen, origin(r)..., widths(r)..., color)
    end

    foreach(child_scene -> draw_background(screen, child_scene), scene.children)
end

function draw_rectangle(screen::Screen, x, y, width, height, color)
    vertices = NTuple{3, Float32}[(x, y, 0), (x + width, y, 0), (x + width, y + height, 0),
                                  (x, y + height, 0)]
    colors = NTuple{3, Float32}[color, color]

    if !isempty(screen.tasks) && screen.tasks[end].type == TriangleTask
        task = screen.tasks[end]
        n = length(task.vertices)
        indices = NTuple{3, Int32}[((n + 0, n + 1, n + 2), (n + 0, n + 2, n + 3))]
        append!(task.indices, indices)
        append!(task.vertices, vertices)
        append!(task.colors, colors)
    else
        indices = NTuple{3, Int32}[(0, 1, 2), (0, 2, 3)]
        task = GGUITask(TriangleTask, vertices, 0.0, 0.0, indices, colors)
        push!(screen.tasks, task)
    end
end

function draw_plot(scene::Scene, screen::Screen, primitive::Combined)
    if to_value(get(primitive, :visible, true))
        if isempty(primitive.plots)
            draw_atomic(scene, screen, primitive)
        else
            zvals = Makie.zvalue2d.(primitive.plots)
            for idx in sortperm(zvals)
                draw_plot(scene, screen, primitive.plots[idx])
            end
        end
    end

    return
end

function draw_atomic(::Scene, ::Screen, x)
    @warn "$(typeof(x)) is not supported by TaichiMakie right now"
end
