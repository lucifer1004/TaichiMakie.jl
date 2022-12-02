module TaichiMakie

using ColorTypes: red, green, blue, alpha, Colorant
using GeometryBasics: origin, widths, Mat, Mat3f, Mat4f, Polygon
using LinearAlgebra
using Reexport: @reexport
@reexport using Makie
using PythonCall: Py, pynew, pycopy!, pyimport, pytruth, pyeq

const np = pynew()
const ti = pynew()

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
