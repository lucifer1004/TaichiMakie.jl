module TaichiMakie

using ColorTypes: red, green, blue, alpha, Colorant, ColorTypes, RGBA
using GeometryBasics: origin, widths, Mat, Mat3f, Mat4f, Polygon
using LinearAlgebra
using Reexport: @reexport
@reexport using Makie
using PythonCall: Py, pynew, pycopy!, pyconvert, pyimport, pytruth, pyeq

const np = pynew()
const ti = pynew()
const ft = pynew()
const DEFAULT_FACE = pynew()

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
    pycopy!(ft, pyimport("freetype"))
    pycopy!(DEFAULT_FACE,
            ft.Face(joinpath(dirname(@__FILE__), "..", "fonts", "SunTimes.ttf")))
    activate!()
end

end # module
