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
    vertices = TaichiField(2, ti.f32, 4)
    push!(vertices, Float32.([x y; x+width y; x+width y+height; x y+height]))

    indices = TaichiField(3, ti.i32, 2)
    push!(indices, Int32.([0 1 2; 0 2 3]))

    screen.ti_canvas.canvas.triangles(vertices.field, color, indices.field)
    destroy!(vertices)
    destroy!(indices)
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
