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

ColorTypes.red(c::NTuple{4, Float32}) = c[1]
ColorTypes.green(c::NTuple{4, Float32}) = c[2]
ColorTypes.blue(c::NTuple{4, Float32}) = c[3]
ColorTypes.alpha(c::NTuple{4, Float32}) = c[4]

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
