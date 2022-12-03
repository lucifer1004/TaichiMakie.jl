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

    if !isempty(screen.tasks) && screen.tasks[end].type == :line &&
       screen.tasks[end].scene == scene &&
       get(screen.tasks[end].attributes, :linewidth, 0.0) ≈ linewidth
        task = screen.tasks[end]
        offset = length(task.vertices)
    end

    n = length(projected_positions)
    if primitive isa LineSegments
        @assert iseven(n)
        indices = [Vec3i(i * 2 - 2 + offset, i * 2 - 1 + offset, 0)
                   for i in 1:(n ÷ 2)]
    else
        indices = [Vec3i(i - 1 + offset, i + offset, 0) for i in 1:(n - 1)]
    end

    vertices = [translate(screen, pos) for pos in projected_positions]

    if color isa AbstractArray
        colors = to_taichi_color.(color)
    else
        colors = fill(to_taichi_color(color), n)
    end

    if !isnothing(task)
        append!(task.indices, indices)
        append!(task.vertices, vertices)
        append!(task.colors, colors)
    else
        task = GGUITask(scene, :line, vertices, indices, colors,
                        Dict(:linewidth => linewidth))
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
    vertices = [translate(screen, pos)]
    colors = [to_taichi_color(color)]
    radius = scale[1]

    if !isempty(screen.tasks) && screen.tasks[end].type == :circle &&
       screen.tasks[end].scene == scene &&
       get(screen.tasks[end].attributes, :markersize, 0.0) == radius
        task = screen.tasks[end]
        append!(task.vertices, vertices)
        append!(task.colors, colors)
    else
        task = GGUITask(scene, :circle, vertices, NTuple{3, Float32}[],
                        colors, Dict(:markersize => radius))
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
                x = glyphpos[1] + (j - 1) * dw
                y = glyphpos[2] + (h - i) * dh
                draw_rectangle(screen, scene, x, y, dw, dh, col)
            end
        end

        return
    end

    restore_ctx!(screen)
    return
end

"""
    regularly_spaced_array_to_range(arr)
If possible, converts `arr` to a range.
If not, returns array unchanged.
"""
function regularly_spaced_array_to_range(arr)
    diffs = unique!(sort!(diff(arr)))
    step = sum(diffs) ./ length(diffs)
    if all(x -> x ≈ step, diffs)
        m, M = extrema(arr)
        if step < zero(step)
            m, M = M, m
        end
        # don't use stop=M, since that may not include M
        return range(m; step = step, length = length(arr))
    else
        return arr
    end
end

regularly_spaced_array_to_range(arr::AbstractRange) = arr

function premultiplied_rgba(a::AbstractArray{<:ColorAlpha})
    return map(premultiplied_rgba, a)
end
premultiplied_rgba(a::AbstractArray{<:Color}) = RGBA.(a)

premultiplied_rgba(r::RGBA) = RGBA(r.r * r.alpha, r.g * r.alpha, r.b * r.alpha, r.alpha)
premultiplied_rgba(c::Colorant) = premultiplied_rgba(RGBA(c))

function draw_atomic(scene::Scene, screen::Screen,
                     @nospecialize(primitive::Union{Heatmap, Image}))
    image = primitive[3][]
    xs, ys = primitive[1][], primitive[2][]
    if !(xs isa AbstractVector)
        l, r = extrema(xs)
        N = size(image, 1)
        xs = range(l, r; length = N + 1)
    else
        xs = regularly_spaced_array_to_range(xs)
    end
    if !(ys isa AbstractVector)
        l, r = extrema(ys)
        N = size(image, 2)
        ys = range(l, r; length = N + 1)
    else
        ys = regularly_spaced_array_to_range(ys)
    end
    model = primitive.model[]::Mat4f
    interpolate = to_value(primitive.interpolate)

    t = Makie.transform_func_obs(primitive)[]
    identity_transform = (t === identity || t isa Tuple && all(x -> x === identity, t)) &&
                         (abs(model[1, 2]) < 1e-15)
    regular_grid = xs isa AbstractRange && ys isa AbstractRange

    if interpolate
        if !regular_grid
            error("$(typeof(primitive).parameters[1]) with interpolate = true with a non-regular grid is not supported right now.")
        end
        if !identity_transform
            error("$(typeof(primitive).parameters[1]) with interpolate = true with a non-identity transform is not supported right now.")
        end
    end

    imsize = ((first(xs), last(xs)), (first(ys), last(ys)))
    # find projected image corners
    # this already takes care of flipping the image to correct cairo orientation
    space = to_value(get(primitive, :space, :data))
    xy = project_position(scene, space, Point2f(first.(imsize)), model)
    xymax = project_position(scene, space, Point2f(last.(imsize)), model)
    w, h = xymax .- xy

    # find projected image corners
    # this already takes care of flipping the image to correct cairo orientation
    space = to_value(get(primitive, :space, :data))
    xys = [project_position(scene, space, Point2f(x, y), model) for x in xs, y in ys]
    colors = to_rgba_image(image, primitive)

    # Note: xs and ys should have size ni+1, nj+1
    ni, nj = size(image)
    if ni + 1 != length(xs) || nj + 1 != length(ys)
        error("Error in conversion pipeline. xs and ys should have size ni+1, nj+1. Found: xs: $(length(xs)), ys: $(length(ys)), ni: $(ni), nj: $(nj)")
    end
    _draw_rect_heatmap(screen, scene, xys, ni, nj, colors)
end

function _draw_rect_heatmap(screen, scene, xys, ni, nj, colors)
    @inbounds for i in 1:ni, j in 1:nj
        p1 = xys[i, j]
        p2 = xys[i + 1, j]
        p3 = xys[i + 1, j + 1]
        p4 = xys[i, j + 1]

        # Rectangles and polygons that are directly adjacent usually show
        # white lines between them due to anti aliasing. To avoid this we
        # increase their size slightly.

        if alpha(colors[i, j]) == 1
            # sign.(p - center) gives the direction in which we need to
            # extend the polygon. (Which may change due to rotations in the
            # model matrix.) (i!=1) etc is used to avoid increasing the
            # outer extent of the heatmap.
            center = 0.25f0 * (p1 + p2 + p3 + p4)
            p1 += sign.(p1 - center) .* Point2f(0.5f0 * (i != 1), 0.5f0 * (j != 1))
            p2 += sign.(p2 - center) .* Point2f(0.5f0 * (i != ni), 0.5f0 * (j != 1))
            p3 += sign.(p3 - center) .* Point2f(0.5f0 * (i != ni), 0.5f0 * (j != nj))
            p4 += sign.(p4 - center) .* Point2f(0.5f0 * (i != 1), 0.5f0 * (j != nj))
        end

        draw_rectangle(screen, scene, p1[1], p1[2], p2[1] - p1[1], p4[2] - p1[2],
                       colors[i, j])
    end
end

function draw_atomic(scene::Scene, screen::Screen, @nospecialize(primitive::Makie.Mesh))
    mesh = primitive[1][]
    if Makie.cameracontrols(scene) isa Union{Camera2D, Makie.PixelCamera, Makie.EmptyCamera}
        draw_mesh2D(scene, screen, primitive, mesh)
    else
        if !haskey(primitive, :faceculling)
            primitive[:faceculling] = Observable(-10)
        end
        draw_mesh3D(scene, screen, primitive, mesh)
    end
    return nothing
end

function draw_mesh2D(scene, screen, @nospecialize(plot), @nospecialize(mesh))
    @get_attribute(plot, (color,))
    color = to_color(hasproperty(mesh, :color) ? mesh.color : color)
    vs = decompose(Point2f, mesh)::Vector{Point2f}
    fs = decompose(GLTriangleFace, mesh)::Vector{GLTriangleFace}
    uv = decompose_uv(mesh)::Union{Nothing, Vector{Vec2f}}
    model = plot.model[]::Mat4f
    colormap = haskey(plot, :colormap) ? to_colormap(plot.colormap[]) : nothing
    colorrange = convert_attribute(to_value(get(plot, :colorrange, nothing)),
                                   key"colorrange"())::Union{Nothing, Vec2f}

    lowclip = get_color_attr(plot, :lowclip)
    highclip = get_color_attr(plot, :highclip)
    nan_color = get_color_attr(plot, :nan_color)

    cols = per_face_colors(color, colormap, colorrange, nothing, fs, nothing, uv,
                           lowclip, highclip, nan_color)

    space = to_value(get(plot, :space, :data))::Symbol
    return draw_mesh2D(scene, screen, cols, space, vs, fs, model)
end

function draw_mesh2D(scene, screen, per_face_cols, space::Symbol,
                     vs::Vector{Point2f}, fs::Vector{GLTriangleFace}, model::Mat4f)
    vertices = Vec3f[]
    colors = Vec3f[]

    for (f, (c1, c2, c3)) in zip(fs, per_face_cols)
        t1, t2, t3 = project_position.(scene, space, vs[f], (model,))
        append!(vertices, [translate(screen, t) for t in [t1, t2, t3]])
        append!(colors, to_taichi_color.([c1, c2, c3]))
    end

    if !isempty(screen.tasks) && screen.tasks[end].type == :triangle
        task = screen.tasks[end]
        n = length(task.vertices)
        indices = [Vec3i(n + 3 * i - 3, n + 3 * i - 2, n + 3 * i - 1)
                   for i in eachindex(fs)]
        append!(task.vertices, vertices)
        append!(task.indices, indices)
        append!(task.colors, colors)
    else
        indices = [Vec3i(3 * i - 3, 3 * i - 2, 3 * i - 1)
                   for i in eachindex(fs)]
        push!(screen.tasks,
              GGUITask(scene, :triangle, vertices, indices, colors))
    end

    return nothing
end

function average_z(positions, face)
    vs = positions[face]
    return sum(v -> v[3], vs) / length(vs)
end

nan2zero(x) = !isnan(x) * x

function draw_mesh3D(scene, screen, attributes, mesh; pos = Vec4f(0), scale = 1.0f0)
    # Priorize colors of the mesh if present
    @get_attribute(attributes, (color,))

    colormap = haskey(attributes, :colormap) ? to_colormap(attributes.colormap[]) : nothing
    colorrange = convert_attribute(to_value(get(attributes, :colorrange, nothing)),
                                   key"colorrange"())::Union{Nothing, Vec2f}
    matcap = to_value(get(attributes, :matcap, nothing))

    color = hasproperty(mesh, :color) ? mesh.color : color
    meshpoints = decompose(Point3f, mesh)::Vector{Point3f}
    meshfaces = decompose(GLTriangleFace, mesh)::Vector{GLTriangleFace}
    meshnormals = decompose_normals(mesh)::Vector{Vec3f}
    meshuvs = texturecoordinates(mesh)::Union{Nothing, Vector{Vec2f}}

    lowclip = get_color_attr(attributes, :lowclip)
    highclip = get_color_attr(attributes, :highclip)
    nan_color = get_color_attr(attributes, :nan_color)

    per_face_col = per_face_colors(color, colormap, colorrange, matcap, meshfaces,
                                   meshnormals, meshuvs,
                                   lowclip, highclip, nan_color)

    @get_attribute(attributes, (shading, diffuse,
                                specular, shininess, faceculling))

    model = attributes.model[]::Mat4f
    space = to_value(get(attributes, :space, :data))::Symbol

    return draw_mesh3D(scene, screen, space, meshpoints, meshfaces, meshnormals,
                       per_face_col, pos, scale,
                       model, shading::Bool, diffuse::Vec3f,
                       specular::Vec3f, shininess::Float32, faceculling::Int)
end

function draw_mesh3D(scene, screen, space, meshpoints, meshfaces, meshnormals, per_face_col,
                     pos, scale,
                     model, shading, diffuse,
                     specular, shininess, faceculling)
    view = ifelse(is_data_space(space), scene.camera.view[], Mat4f(I))
    projection = Makie.space_to_clip(scene.camera, space, false)
    i = Vec(1, 2, 3)
    normalmatrix = transpose(inv(view[i, i] * model[i, i]))

    # Mesh data
    # transform to view/camera space
    func = Makie.transform_func_obs(scene)[]
    # pass func as argument to function, so that we get a function barrier
    # and have `func` be fully typed inside closure
    vs = broadcast(meshpoints, (func,)) do v, f
        # Should v get a nan2zero?
        v = Makie.apply_transform(f, v)
        p4d = to_ndim(Vec4f, scale .* to_ndim(Vec3f, v, 0.0f0), 1.0f0)
        return view * (model * p4d .+ to_ndim(Vec4f, pos, 0.0f0))
    end

    ns = map(n -> normalize(normalmatrix * n), meshnormals)
    # Light math happens in view/camera space
    pointlight = Makie.get_point_light(scene)
    lightposition = if !isnothing(pointlight)
        pointlight.position[]
    else
        Vec3f(0)
    end
    lightcol = if !isnothing(pointlight)
        pointlight.radiance[]
    else
        Vec3f(0)
    end

    ambientlight = Makie.get_ambient_light(scene)
    ambient = if !isnothing(ambientlight)
        c = ambientlight.color[]
        Vec3f(c.r, c.g, c.b)
    else
        Vec3f(0)
    end

    lightpos = (view * to_ndim(Vec4f, lightposition, 1.0))[Vec(1, 2, 3)]

    # Camera to screen space
    ts = map(vs) do v
        clip = projection * v
        @inbounds begin
            p = (clip ./ clip[4])[Vec(1, 2)]
            p_yflip = Vec2f(p[1], -p[2])
            p_0_to_1 = (p_yflip .+ 1.0f0) ./ 2.0f0
        end
        p = p_0_to_1 .* scene.camera.resolution[]
        return Vec3f(p[1], p[2], clip[3])
    end

    # Approximate zorder
    average_zs = map(f -> average_z(ts, f), meshfaces)
    zorder = sortperm(average_zs)

    # Face culling
    zorder = filter(i -> any(last.(ns[meshfaces[i]]) .> faceculling), zorder)

    draw_pattern(screen, scene,
                 zorder, shading, meshfaces, ts, per_face_col,
                 ns, vs,
                 lightpos, lightcol,
                 shininess, diffuse,
                 ambient, specular)
    return
end

function _calculate_shaded_vertexcolors(N, v, c, lightpos, ambient, diffuse, specular,
                                        shininess)
    L = normalize(lightpos .- v[Vec(1, 2, 3)])
    diff_coeff = max(dot(L, N), 0.0f0)
    H = normalize(L + normalize(-v[Vec(1, 2, 3)]))
    spec_coeff = max(dot(H, N), 0.0f0)^shininess
    c = RGBAf(c)
    new_c_part1 = (ambient .+ diff_coeff .* diffuse) .* Vec3f(c.r, c.g, c.b) #.+
    new_c = new_c_part1 .+ specular * spec_coeff
    return RGBAf(new_c..., c.alpha)
end

function draw_pattern(screen, scene,
                      zorder, shading, meshfaces, ts, per_face_col,
                      ns, vs,
                      lightpos, lightcol,
                      shininess, diffuse,
                      ambient, specular)
    vertices = Vec3f[]
    colors = Vec3f[]

    for k in reverse(zorder)
        f = meshfaces[k]
        # avoid SizedVector through Face indexing
        t1 = ts[f[1]]
        t2 = ts[f[2]]
        t3 = ts[f[3]]

        facecolors = per_face_col[k]
        # light calculation
        if shading
            c1, c2, c3 = Base.Cartesian.@ntuple 3 i->begin
                # these face index expressions currently allocate for SizedVectors
                # if done like `ns[f]`
                N = ns[f[i]]
                v = vs[f[i]]
                c = facecolors[i]
                _calculate_shaded_vertexcolors(N, v, c, lightpos, ambient, diffuse,
                                               specular, shininess)
            end
        else
            c1, c2, c3 = facecolors
        end

        append!(vertices, [t1, t2, t3])
        # append!(vertices, [translate(screen, t) for t in [t1, t2, t3]])
        append!(colors, to_taichi_color.([c1, c2, c3]))
    end

    attr = Dict(:lightpos => lightpos,
                :lightcol => lightcol,
                :ambient => ambient,
                :diffuse => diffuse,
                :shininess => shininess,
                :specular => specular)

    if !isempty(screen.tasks) && screen.tasks[end].type == :mesh &&
       screen.tasks[end].scene == scene && screen.tasks[end].attributes == attr
        task = screen.tasks[end]
        n = length(task.vertices)
        indices = [Vec3i(n + i * 3 - 3, n + i * 3 - 2, n + i * 3 - 1)
                   for i in 1:length(zorder)]
        append!(task.vertices, vertices)
        append!(task.colors, colors)
        append!(task.indices, indices)
    else
        indices = [Vec3i(i * 3 - 3, i * 3 - 2, i * 3 - 1) for i in 1:length(zorder)]
        push!(screen.tasks, GGUITask(scene, :mesh, vertices, indices, colors, attr))
    end
end

################################################################################
#                                   Surface                                    #
################################################################################

function draw_atomic(scene::Scene, screen::Screen, @nospecialize(primitive::Makie.Surface))
    # Pretend the surface plot is a mesh plot and plot that instead
    mesh = surface2mesh(primitive[1][], primitive[2][], primitive[3][])
    old = primitive[:color]
    if old[] === nothing
        primitive[:color] = primitive[3]
    end
    if !haskey(primitive, :faceculling)
        primitive[:faceculling] = Observable(-10)
    end
    draw_mesh3D(scene, screen, primitive, mesh)
    primitive[:color] = old
    return nothing
end

function surface2mesh(xs, ys, zs::AbstractMatrix)
    ps = Makie.matrix_grid(p -> nan2zero.(p), xs, ys, zs)
    rect = Tesselation(Rect2f(0, 0, 1, 1), size(zs))
    faces = decompose(QuadFace{Int}, rect)
    uv = map(x -> Vec2f(1.0f0 - x[2], 1.0f0 - x[1]), decompose_uv(rect))
    uvm = GeometryBasics.Mesh(GeometryBasics.meta(ps; uv = uv), faces)
    return GeometryBasics.normal_mesh(uvm)
end

################################################################################
#                                 MeshScatter                                  #
################################################################################

function draw_atomic(scene::Scene, screen::Screen,
                     @nospecialize(primitive::Makie.MeshScatter))
    @get_attribute(primitive, (color, model, marker, markersize, rotations))

    if color isa AbstractArray{<:Number}
        color = numbers_to_colors(color, primitive)
    end

    m = convert_attribute(marker, key"marker"(), key"meshscatter"())
    pos = primitive[1][]
    # For correct z-ordering we need to be in view/camera or screen space
    model = copy(model)
    view = scene.camera.view[]

    zorder = sortperm(pos;
                      by = p -> begin
                          p4d = to_ndim(Vec4f, to_ndim(Vec3f, p, 0.0f0), 1.0f0)
                          cam_pos = view * model * p4d
                          cam_pos[3] / cam_pos[4]
                      end, rev = false)

    submesh = Attributes(; model = model,
                         color = color,
                         shading = primitive.shading, diffuse = primitive.diffuse,
                         specular = primitive.specular, shininess = primitive.shininess,
                         faceculling = get(primitive, :faceculling, -10))

    if !(rotations isa Vector)
        R = Makie.rotationmatrix4(to_rotation(rotations))
        submesh[:model] = model * R
    end
    scales = primitive[:markersize][]

    for i in zorder
        p = pos[i]
        if color isa AbstractVector
            submesh[:color] = color[i]
        end
        if rotations isa Vector
            R = Makie.rotationmatrix4(to_rotation(rotations[i]))
            submesh[:model] = model * R
        end
        scale = markersize isa Vector ? markersize[i] : markersize

        draw_mesh3D(scene, screen, submesh, m; pos = p,
                    scale = scale isa Real ? Vec3f(scale) : to_ndim(Vec3f, scale, 1.0f0))
    end

    return nothing
end
