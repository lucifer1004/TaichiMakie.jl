function draw_atomic(scene::Scene, screen::Screen,
                     @nospecialize(primitive::Union{Lines, LineSegments}))
    @get_attribute(primitive, (color, linewidth, linestyle))
    linewidth /= minimum(size(screen))
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

    w, h = size(screen)
    vertices = [Float32.((projected_positions[i][1] / w,
                          projected_positions[i][2] / h, 0))
                for i in 1:n]

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
        task = GGUITask(LineTask, vertices, linewidth, 0.0, indices, colors)
        push!(screen.tasks, task)
    end
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
    w, h = size(screen)
    vertices = [Float32.((pos[1] / w, pos[2] / h, 0))]
    colors = [
        Float32.((1 .-
                  (1 .- (red(strokecolor), green(strokecolor), blue(strokecolor))) .*
                  alpha(strokecolor))),
    ]
    radius = scale[1] / (2 * min(w, h))

    if !isempty(screen.tasks) && screen.tasks[end].type == CircleTask &&
       screen.tasks[end].markersize == radius
        task = screen.tasks[end]
        append!(task.vertices, vertices)
        append!(task.colors, colors)
    else
        task = GGUITask(CircleTask, vertices, 0.0, radius, NTuple{3, Float32}[], colors)
        push!(screen.tasks, task)
    end

    return
end
