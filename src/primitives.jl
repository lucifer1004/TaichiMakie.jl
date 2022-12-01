function draw_atomic(scene::Scene, screen::Screen,
                     @nospecialize(primitive::Union{Lines, LineSegments}))
    fields = @get_attribute(primitive, (color, linewidth, linestyle))
    linestyle = Makie.convert_attribute(linestyle, Makie.key"linestyle"())
    model = primitive[:model][]
    positions = primitive[1][]

    isempty(positions) && return

    space = to_value(get(primitive, :space, :data))
    projected_positions = project_position.(Ref(scene), Ref(space), positions, Ref(model))

    if color isa AbstractArray{<:Number}
        color = numbers_to_colors(color, primitive)
    end

    n = length(projected_positions)
    if primitive isa LineSegments
        @assert iseven(n)
        ti_indices = [Int32((i - 1) * 2 + j - 1) for i in 1:(n ÷ 2), j in 1:2]
        indices = TaichiField(2, ti.i32, (n ÷ 2,))
    else
        ti_indices = [Int32(i + j - 2) for i in 1:(n - 1), j in 1:2]
        indices = TaichiField(2, ti.i32, (n - 1,))
    end
    push!(indices, ti_indices)

    ti_positions = zeros(Float32, n, 2)
    w, h = size(screen)
    for i in 1:n
        ti_positions[i, 1] = projected_positions[i][1] / w
        ti_positions[i, 2] = projected_positions[i][2] / h
    end

    vertices = TaichiField(2, ti.f32, (n,))
    push!(vertices, ti_positions)

    linewidth /= minimum(size(screen))

    if color isa AbstractArray
        ti_colors = zeros(Float32, n, 3)
        for i in 1:n
            ti_colors[i, 1] = 1 - (1 - red(color[i])) * alpha(color[i])
            ti_colors[i, 2] = 1 - (1 - green(color[i])) * alpha(color[i])
            ti_colors[i, 3] = 1 - (1 - blue(color[i])) * alpha(color[i])
        end

        colors = TaichiField(3, ti.f32, (n,))
        push!(colors, ti_colors)

        screen.ti_canvas.canvas.lines(vertices.field, linewidth,
                                      indices.field;
                                      per_vertex_color = colors.field)

        destroy!(colors)
    else
        color = 1 .- (1 .- (red(color), green(color), blue(color))) .* alpha(color)
        screen.ti_canvas.canvas.lines(vertices.field, linewidth,
                                      indices.field, color = color)
    end

    destroy!(indices)
    destroy!(vertices)
end

function draw_atomic(scene::Scene, screen::Screen, @nospecialize(primitive::Scatter))
    fields = @get_attribute(primitive,
                            (color, markersize, strokecolor, strokewidth, marker,
                             marker_offset, rotations))
    @get_attribute(primitive, (transform_marker,))

    model = primitive[:model][]
    positions = primitive[1][]
    isempty(positions) && return
    size_model = transform_marker ? model : Mat4f(LinearAlgebra.I)

    font = to_font(to_value(get(primitive, :font, Makie.defaultfont())))

    colors = if color isa AbstractArray{<:Number}
        numbers_to_colors(color, primitive)
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
        draw_marker(screen, marker_converted, pos, scale, strokecolor, strokewidth,
                    offset, rotation)
    end
    return
end

function draw_marker(screen, shape, pos, scale, strokecolor, strokewidth,
                     marker_offset, rotation)
    marker_offset = marker_offset + scale ./ 2
    pos += Point2f(marker_offset[1], -marker_offset[2])
    vertices = TaichiField(2, ti.f32, (1,))
    w, h = size(screen)
    push!(vertices, [pos[1] / w pos[2] / h])
    color = 1 .-
            (1 .- (red(strokecolor), green(strokecolor), blue(strokecolor))) .*
            alpha(strokecolor)
    radius = scale[1] / (2 * min(w, h))
    screen.ti_canvas.canvas.circles(vertices.field, radius, color)
    destroy!(vertices)

    return
end
