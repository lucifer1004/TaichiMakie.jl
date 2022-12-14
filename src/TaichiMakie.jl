module TaichiMakie

using ColorTypes: red, green, blue, alpha, ARGB32, Color, Colorant, ColorAlpha, ColorTypes,
                  RGBA
using FreeTypeAbstraction
using GeometryBasics: decompose_uv, decompose_normals, texturecoordinates, origin, widths,
                      GLTriangleFace, Mat,
                      Mat3f, Mat4f,
                      Polygon
using LinearAlgebra
using Reexport: @reexport
@reexport using Makie
using Makie: is_data_space, numbers_to_colors
using PythonCall: pynew, pycopy!, pyconvert, pyimport, pytruth, Py, PyArray

const np = pynew()
const ti = pynew()
const Vec3i = Vec3{Int32}

include("fonts.jl")
include("taichi_utils.jl")
include("screen.jl")
include("infrastructure.jl")
include("display.jl")
include("primitives.jl")
include("utils.jl")

function __init__()
    pycopy!(np, pyimport("numpy"))
    pycopy!(ti, pyimport("taichi"))
    activate!()
end

end # module
