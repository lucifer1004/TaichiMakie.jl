function draw_atomic(scene::Scene, screen::Screen,
                     @nospecialize(primitive::Union{Lines, LineSegments}))
    @get_attribute(primitive, (color, linewidth, linestyle))
    linestyle = Makie.convert_attribute(linestyle, Makie.key"linestyle"())
    model = primitive[:model][]
    positions = primitive[1][]

    isempty(positions) && return

    space = to_value(get(primitive, :space, :data))
    projected_positions = project_position.(Ref(scene), Ref(space), positions, Ref(model))

    if color isa AbstractArray{<:Number}
        color = numbers_to_colors(color, primitive)
    end

    offset = 0
    task = nothing

    if !isempty(screen.tasks) && screen.tasks[end].type == LineTask &&
       screen.tasks[end].scene == scene &&
       screen.tasks[end].linewidth ≈ linewidth
        task = screen.tasks[end]
        offset = length(task.vertices)
    end

    n = length(projected_positions)
    if primitive isa LineSegments
        @assert iseven(n)
        indices = [Int32.((i * 2 - 2 + offset, i * 2 - 1 + offset, 0))
                   for i in 1:(n ÷ 2)]
    else
        indices = [Int32.((i - 1 + offset, i + offset, 0)) for i in 1:(n - 1)]
    end

    vertices = map(1:n) do i
        Float32.((screen.translate[1, 1] * projected_positions[i][1] +
                  screen.translate[1, 2] * projected_positions[i][2] +
                  screen.translate[1, 3],
                  screen.translate[2, 1] * projected_positions[i][1] +
                  screen.translate[2, 2] * projected_positions[i][2] +
                  screen.translate[2, 3],
                  0.0))
    end

    if color isa AbstractArray
        colors = [Float32.((1 - (1 - red(color[i])) * alpha(color[i]),
                            1 - (1 - green(color[i])) * alpha(color[i]),
                            1 - (1 - blue(color[i])) * alpha(color[i])))
                  for i in eachindex(color)]
    else
        color = 1 .- (1 .- (red(color), green(color), blue(color))) .* alpha(color)
        colors = fill(Float32.(color), length(indices))
    end

    if !isnothing(task)
        append!(task.indices, indices)
        append!(task.vertices, vertices)
        append!(task.colors, colors)
    else
        task = GGUITask(scene, LineTask, vertices, linewidth, 0.0, indices, colors)
        push!(screen.tasks, task)
    end
end

function draw_atomic(scene::Scene, screen::Screen, @nospecialize(primitive::Scatter))
    @get_attribute(primitive,
                   (color, markersize, strokecolor, strokewidth, marker,
                    marker_offset, rotations))
    @get_attribute(primitive, (transform_marker,))

    model = primitive[:model][]
    positions = primitive[1][]
    isempty(positions) && return
    size_model = transform_marker ? model : Mat4f(LinearAlgebra.I)

    font = to_font(to_value(get(primitive, :font, Makie.defaultfont())))

    colors = if color isa AbstractArray{<:Number}
        Makie.numbers_to_colors(color, primitive)
    else
        color
    end

    markerspace = to_value(get(primitive, :markerspace, :pixel))
    space = to_value(get(primitive, :space, :data))

    transfunc = scene.transformation.transform_func[]

    marker_conv = _marker_convert(marker)

    draw_atomic_scatter(scene, screen, transfunc, colors, markersize, strokecolor,
                        strokewidth,
                        marker_conv, marker_offset, rotations, model, positions, size_model,
                        font, markerspace, space)
end

# an array of markers is converted to string by itself, which is inconvenient for the iteration logic
function _marker_convert(markers::AbstractArray)
    map(m -> convert_attribute(m, key"marker"(), key"scatter"()), markers)
end
_marker_convert(marker) = convert_attribute(marker, key"marker"(), key"scatter"())
# image arrays need to be converted as a whole
function _marker_convert(marker::AbstractMatrix{<:Colorant})
    [convert_attribute(marker, key"marker"(), key"scatter"())]
end

function draw_atomic_scatter(scene, screen, transfunc, colors, markersize, strokecolor,
                             strokewidth, marker, marker_offset, rotations, model,
                             positions, size_model, font, markerspace, space)
    broadcast_foreach(positions, colors, markersize, strokecolor,
                      strokewidth, marker, marker_offset,
                      remove_billboard(rotations)) do point, col,
                                                      markersize, strokecolor, strokewidth,
                                                      m, mo, rotation
        scale = project_scale(scene, markerspace, markersize, size_model)
        offset = project_scale(scene, markerspace, mo, size_model)

        pos = project_position(scene, transfunc, space, point, model)
        isnan(pos) && return

        marker_converted = Makie.to_spritemarker(m)
        draw_marker(scene, screen, marker_converted, pos, scale, col, strokecolor,
                    strokewidth,
                    offset, rotation)
    end
    return
end

function draw_marker(scene, screen, shape, pos, scale, color, strokecolor, strokewidth,
                     marker_offset, rotation)
    marker_offset = marker_offset + scale ./ 2
    pos += Point2f(marker_offset[1], -marker_offset[2])
    vertices = [
        Float32.((screen.translate[1, 1] * pos[1] +
                  screen.translate[1, 2] * pos[2] +
                  screen.translate[1, 3],
                  screen.translate[2, 1] * pos[1] +
                  screen.translate[2, 2] * pos[2] +
                  screen.translate[2, 3],
                  0.0)),
    ]
    colors = [
        Float32.((1 .-
                  (1 .- (red(color), green(color), blue(color))) .*
                  alpha(color))),
    ]
    radius = scale[1]

    if !isempty(screen.tasks) && screen.tasks[end].type == CircleTask &&
       screen.tasks[end].scene == scene &&
       screen.tasks[end].markersize == radius
        task = screen.tasks[end]
        append!(task.vertices, vertices)
        append!(task.colors, colors)
    else
        task = GGUITask(scene, CircleTask, vertices, 0.0, radius, NTuple{3, Float32}[],
                        colors)
        push!(screen.tasks, task)
    end

    return
end

function draw_atomic(scene::Scene, screen::Screen,
                     @nospecialize(primitive::Makie.Text{
                                                         <:Tuple{
                                                                 <:Union{
                                                                         AbstractArray{
                                                                                       <:Makie.GlyphCollection
                                                                                       },
                                                                         Makie.GlyphCollection
                                                                         }}}))
    @get_attribute(primitive, (rotation, model, space, markerspace, offset))
    position = primitive.position[]
    # use cached glyph info
    glyph_collection = to_value(primitive[1])

    draw_glyph_collection(screen, scene, position, glyph_collection,
                          remove_billboard(rotation),
                          model, space, markerspace, offset)

    return nothing
end

function draw_glyph_collection(screen, scene, positions, glyph_collections::AbstractArray,
                               rotation,
                               model::Mat, space, markerspace, offset)

    # TODO: why is the Ref around model necessary? doesn't broadcast_foreach handle staticarrays matrices?
    broadcast_foreach(positions, glyph_collections, rotation, Ref(model), space,
                      markerspace, offset) do pos, glayout, ro, mo, sp, msp, off
        return draw_glyph_collection(screen, scene, pos, glayout, ro, mo, sp, msp, off)
    end
end

_deref(x) = x
_deref(x::Ref) = x[]

function draw_glyph_collection(screen, scene, position, glyph_collection, rotation, _model,
                               space, markerspace,
                               offsets)
    glyphs = glyph_collection.glyphs
    glyphoffsets = glyph_collection.origins
    fonts = glyph_collection.fonts
    rotations = glyph_collection.rotations
    scales = glyph_collection.scales
    colors = glyph_collection.colors
    strokewidths = glyph_collection.strokewidths
    strokecolors = glyph_collection.strokecolors

    model = _deref(_model)
    model33 = model[Vec(1, 2, 3), Vec(1, 2, 3)]
    id = Mat4f(I)

    glyph_pos = let
        transform_func = scene.transformation.transform_func[]
        p = Makie.apply_transform(transform_func, position)

        Makie.clip_to_space(scene.camera, markerspace) *
        Makie.space_to_clip(scene.camera, space) *
        model * to_ndim(Point4f, to_ndim(Point3f, p, 0), 1)
    end

    save_ctx!(screen)
    broadcast_foreach(glyphs, glyphoffsets, fonts, rotations, scales, colors, strokewidths,
                      strokecolors,
                      offsets) do glyph,
                                  glyphoffset, font, rotation, scale, color, strokewidth,
                                  strokecolor, offset
        p3_offset = to_ndim(Point3f, offset, 0)
        glyph == 0 && return
        gp3 = glyph_pos[Vec(1, 2, 3)] ./ glyph_pos[4] .+
              model33 * (glyphoffset .+ p3_offset)

        scale3 = scale isa Number ? Point3f(scale, scale, 0) : to_ndim(Point3f, scale, 0)
        glyphpos = _project_position(scene, markerspace, gp3, id, false)
        glyphdata, metric = getbitmap(glyph)
        h, w = size(glyphdata)

        dw = scale3[1] / DEFAULT_GLYPH_PIXEL_SIZE[]
        dh = scale3[2] / DEFAULT_GLYPH_PIXEL_SIZE[]
        color = rgbatuple(color)
        for i in 1:h, j in 1:w
            if glyphdata[i, j] > 0
                alpha_ = glyphdata[i, j] / 255 * alpha(color)
                col = 1 .- (1 .- (red(color), blue(color), green(color))) .* alpha_
                x0 = glyphpos[1] + (j - 1) * dw
                y0 = glyphpos[2] + (h - i) * dh
                x = screen.translate[1, 1] * x0 + screen.translate[1, 2] * y0 +
                    screen.translate[1, 3]
                y = screen.translate[2, 1] * x0 + screen.translate[2, 2] * y0 +
                    screen.translate[2, 3]
                draw_rectangle(screen, scene, x, y, dw * screen.translate[1, 1],
                               dh * screen.translate[2, 2], col)
            end
        end

        return
    end

    restore_ctx!(screen)
    return
end
