module TaichiMakie

using ColorTypes: red, green, blue, alpha, Color, Colorant, ColorAlpha, ColorTypes, RGBA
using FreeTypeAbstraction
using GeometryBasics: origin, widths, Mat, Mat3f, Mat4f, Polygon
using LinearAlgebra
using Reexport: @reexport
@reexport using Makie
using PythonCall: Py, pynew, pycopy!, pyconvert, pyimport, pytruth, pyeq

const np = pynew()
const ti = pynew()

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
    DEFAULT_FACE[] = FTFont(joinpath(@__DIR__, "..", "fonts", "cmunrm.ttf"))
    FreeTypeAbstraction.set_pixelsize(DEFAULT_FACE[], DEFAULT_GLYPH_PIXEL_SIZE[])
    activate!()
end

end # module
