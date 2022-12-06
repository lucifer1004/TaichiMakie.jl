function translate(screen, vertex)
    return Vec3f(screen.translate[1, 1] * vertex[1] +
                 screen.translate[1, 2] * vertex[2] +
                 screen.translate[1, 3],
                 screen.translate[2, 1] * vertex[1] +
                 screen.translate[2, 2] * vertex[2] +
                 screen.translate[2, 3],
                 0.0)
end

function project_position(scene, transform_func::T, space, point, model,
                          yflip::Bool = false) where {T}
    point = Makie.apply_transform(transform_func, point)
    _project_position(scene, space, point, model, yflip)
end

function _project_position(scene, space, point, model, yflip)
    res = scene.camera.resolution[]
    p4d = to_ndim(Vec4f, to_ndim(Vec3f, point, 0.0f0), 1.0f0)
    clip = Makie.space_to_clip(scene.camera, space) * model * p4d
    @inbounds begin
        # between -1 and 1
        p = (clip ./ clip[4])[Vec(1, 2)]
        # flip y to match cairo
        p_yflip = Vec2f(p[1], (1.0f0 - 2.0f0 * yflip) * p[2])
        # normalize to between 0 and 1
        p_0_to_1 = (p_yflip .+ 1.0f0) ./ 2.0f0
    end
    # multiply with scene resolution for final position
    return p_0_to_1 .* res
end

function project_position(scene, space, point, model, yflip::Bool = false)
    project_position(scene, scene.transformation.transform_func[], space, point, model,
                     yflip)
end

function project_scale(scene::Scene, space, s::Number, model = Mat4f(I))
    project_scale(scene, space, Vec2f(s), model)
end

function project_scale(scene::Scene, space, s, model = Mat4f(I))
    p4d = model * to_ndim(Vec4f, s, 0.0f0)
    if Makie.is_data_space(space)
        @inbounds p = (scene.camera.projectionview[] * p4d)[Vec(1, 2)]
        return p .* scene.camera.resolution[] .* 0.5
    elseif Makie.is_pixel_space(space)
        return p4d[Vec(1, 2)]
    elseif Makie.is_relative_space(space)
        return p4d[Vec(1, 2)] .* scene.camera.resolution[]
    else # clip
        return p4d[Vec(1, 2)] .* scene.camera.resolution[] .* 0.5f0
    end
end

function project_rect(scene, space, rect::Rect, model)
    mini = project_position(scene, space, minimum(rect), model)
    maxi = project_position(scene, space, maximum(rect), model)
    return Rect(mini, maxi .- mini)
end

function project_polygon(scene, space, poly::P, model) where {P <: Polygon}
    ext = decompose(Point2f, poly.exterior)
    interiors = decompose.(Point2f, poly.interiors)
    Polygon(Point2f.(project_position.(Ref(scene), space, ext, Ref(model))),
            [Point2f.(project_position.(Ref(scene), space, interior, Ref(model)))
             for interior in interiors])
end

function to_2d_rotation(x)
    quat = to_rotation(x)
    return -Makie.quaternion_to_2d_angle(quat)
end

function to_2d_rotation(::Makie.Billboard)
    @warn "This should not be reachable!"
    0
end

remove_billboard(x) = x
remove_billboard(b::Makie.Billboard) = b.rotation

to_2d_rotation(quat::Makie.Quaternion) = -Makie.quaternion_to_2d_angle(quat)

# TODO: this is a hack around a hack.
# Makie encodes the transformation from a 2-vector
# to a quaternion as a rotation around the Y-axis,
# when it should be a rotation around the X-axis.
# Since I don't know how to fix this in GLMakie,
# I've reversed the order of arguments to atan,
# such that our behaviour is consistent with GLMakie's.
to_2d_rotation(vec::Vec2f) = atan(vec[1], vec[2])

to_2d_rotation(n::Real) = n

ColorTypes.red(c::Vec{3, Float32}) = c[1]
ColorTypes.green(c::Vec{3, Float32}) = c[2]
ColorTypes.blue(c::Vec{3, Float32}) = c[3]
ColorTypes.alpha(c::Vec{3, Float32}) = 1.0

ColorTypes.red(c::NTuple{3, Float32}) = c[1]
ColorTypes.green(c::NTuple{3, Float32}) = c[2]
ColorTypes.blue(c::NTuple{3, Float32}) = c[3]
ColorTypes.alpha(c::NTuple{3, Float32}) = 1.0

ColorTypes.red(c::NTuple{3, Float64}) = c[1]
ColorTypes.green(c::NTuple{3, Float64}) = c[2]
ColorTypes.blue(c::NTuple{3, Float64}) = c[3]
ColorTypes.alpha(c::NTuple{3, Float64}) = 1.0

ColorTypes.red(c::NTuple{4, Float32}) = c[1]
ColorTypes.green(c::NTuple{4, Float32}) = c[2]
ColorTypes.blue(c::NTuple{4, Float32}) = c[3]
ColorTypes.alpha(c::NTuple{4, Float32}) = c[4]

ColorTypes.red(c::NTuple{4, Float64}) = c[1]
ColorTypes.green(c::NTuple{4, Float64}) = c[2]
ColorTypes.blue(c::NTuple{4, Float64}) = c[3]
ColorTypes.alpha(c::NTuple{4, Float64}) = c[4]

ColorTypes.red(c::AbstractVector) = c[1]
ColorTypes.green(c::AbstractVector) = c[2]
ColorTypes.blue(c::AbstractVector) = c[3]
ColorTypes.alpha(c::AbstractVector) = length(c) >= 4 ? c[4] : 1.0

function to_taichi_color(c)
    r = clamp(red(c), 0, 1)
    g = clamp(green(c), 0, 1)
    b = clamp(blue(c), 0, 1)
    a = clamp(alpha(c), 0, 1)
    return Vec3f(1 - (1 - r) * a, 1 - (1 - g) * a, 1 - (1 - b) * a)
end

function rgbatuple(c::Colorant)
    rgba = RGBA(c)
    red(rgba), green(rgba), blue(rgba), alpha(rgba)
end

function rgbatuple(c)
    colorant = to_color(c)
    if !(colorant isa Colorant)
        error("Can't convert $(c) to a colorant")
    end
    return rgbatuple(colorant)
end

function to_rgba_image(img::AbstractMatrix{<:AbstractFloat}, attributes)
    Makie.@get_attribute attributes (colormap, colorrange, nan_color, lowclip, highclip)

    nan_color = Makie.to_color(nan_color)
    lowclip = isnothing(lowclip) ? lowclip : Makie.to_color(lowclip)
    highclip = isnothing(highclip) ? highclip : Makie.to_color(highclip)

    [get_rgba_pixel(pixel, colormap, colorrange, nan_color, lowclip, highclip)
     for pixel in img]
end

to_rgba_image(img::AbstractMatrix{<:Colorant}, attributes) = RGBAf.(img)

function get_rgba_pixel(pixel, colormap, colorrange, nan_color, lowclip, highclip)
    vmin, vmax = colorrange
    if isnan(pixel)
        RGBAf(nan_color)
    elseif pixel < vmin && !isnothing(lowclip)
        RGBAf(lowclip)
    elseif pixel > vmax && !isnothing(highclip)
        RGBAf(highclip)
    else
        RGBAf(Makie.interpolated_getindex(colormap, pixel, colorrange))
    end
end

################################################################################
#                                Mesh handling                                 #
################################################################################

struct FaceIterator{Iteration, T, F, ET} <: AbstractVector{ET}
    data::T
    faces::F
end

function (::Type{FaceIterator{Typ}})(data::T, faces::F) where {Typ, T, F}
    FaceIterator{Typ, T, F}(data, faces)
end
function (::Type{FaceIterator{Typ, T, F}})(data::AbstractVector, faces::F) where {Typ, F, T}
    FaceIterator{Typ, T, F, NTuple{3, eltype(data)}}(data, faces)
end
function (::Type{FaceIterator{Typ, T, F}})(data::T, faces::F) where {Typ, T, F}
    FaceIterator{Typ, T, F, NTuple{3, T}}(data, faces)
end
function FaceIterator(data::AbstractVector, faces)
    if length(data) == length(faces)
        FaceIterator{:PerFace}(data, faces)
    else
        FaceIterator{:PerVert}(data, faces)
    end
end

Base.size(fi::FaceIterator) = size(fi.faces)
Base.getindex(fi::FaceIterator{:PerFace}, i::Integer) = fi.data[i]
Base.getindex(fi::FaceIterator{:PerVert}, i::Integer) = fi.data[fi.faces[i]]
Base.getindex(fi::FaceIterator{:Const}, i::Integer) = ntuple(i -> fi.data, 3)

color_or_nothing(c) = isnothing(c) ? nothing : to_color(c)
function get_color_attr(attributes, attribute)::Union{Nothing, RGBAf}
    return color_or_nothing(to_value(get(attributes, attribute, nothing)))
end

function per_face_colors(color, colormap, colorrange, matcap, faces, normals, uv,
                         lowclip = nothing, highclip = nothing, nan_color = nothing)
    if matcap !== nothing
        wsize = reverse(size(matcap))
        wh = wsize .- 1
        cvec = map(normals) do n
            muv = 0.5n[Vec(1, 2)] .+ Vec2f(0.5)
            x, y = clamp.(round.(Int, Tuple(muv) .* wh) .+ 1, 1, wh)
            return matcap[end - (y - 1), x]
        end
        return FaceIterator(cvec, faces)
    elseif color isa Colorant
        return FaceIterator{:Const}(color, faces)
    elseif color isa AbstractArray
        if color isa AbstractVector{<:Colorant}
            return FaceIterator(color, faces)
        elseif color isa AbstractArray{<:Number}
            low, high = extrema(colorrange)
            cvec = map(color[:]) do c
                if isnan(c) && nan_color !== nothing
                    return nan_color
                elseif c < low && lowclip !== nothing
                    return lowclip
                elseif c > high && highclip !== nothing
                    return highclip
                else
                    Makie.interpolated_getindex(colormap, c, colorrange)
                end
            end
            return FaceIterator(cvec, faces)
        elseif color isa Makie.AbstractPattern
            # let next level extend and fill with CairoPattern
            return color
        elseif color isa AbstractMatrix{<:Colorant} && uv !== nothing
            wsize = reverse(size(color))
            wh = wsize .- 1
            cvec = map(uv) do uv
                x, y = clamp.(round.(Int, Tuple(uv) .* wh) .+ 1, 1, wh)
                return color[end - (y - 1), x]
            end
            # TODO This is wrong and doesn't actually interpolate
            # Inside the triangle sampling the color image
            return FaceIterator(cvec, faces)
        end
    end
    error("Unsupported Color type: $(typeof(color))")
end

"""
Finds a font that can represent the unicode character!
Returns Makie.defaultfont() if not representable!
"""
function best_font(c::Char, font = Makie.defaultfont())
    if Makie.FreeType.FT_Get_Char_Index(font, c) == 0
        for afont in Makie.alternativefonts()
            if Makie.FreeType.FT_Get_Char_Index(afont, c) != 0
                return afont
            end
        end
        return Makie.defaultfont()
    end
    return font
end