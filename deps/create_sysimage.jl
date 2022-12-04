import Pkg

Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.instantiate()

using PackageCompiler

create_sysimage(["TaichiMakie"], sysimage_path = "taichi_makie.so",
                precompile_execution_file = joinpath((@__DIR__, "..", "examples",
                                                      "visible.jl")))
