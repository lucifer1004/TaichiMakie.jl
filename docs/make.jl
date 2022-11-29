using TaichiMakie
using Documenter

DocMeta.setdocmeta!(TaichiMakie, :DocTestSetup, :(using TaichiMakie); recursive=true)

makedocs(;
    modules=[TaichiMakie],
    authors="Gabriel Wu <wuzihua@pku.edu.cn> and contributors",
    repo="https://github.com/lucifer1004/TaichiMakie.jl/blob/{commit}{path}#{line}",
    sitename="TaichiMakie.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://lucifer1004.github.io/TaichiMakie.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/lucifer1004/TaichiMakie.jl",
    devbranch="main",
)
