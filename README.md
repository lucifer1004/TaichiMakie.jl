# TaichiMakie

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://lucifer1004.github.io/TaichiMakie.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://lucifer1004.github.io/TaichiMakie.jl/dev/)
[![Build Status](https://github.com/lucifer1004/TaichiMakie.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lucifer1004/TaichiMakie.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/lucifer1004/TaichiMakie.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/lucifer1004/TaichiMakie.jl)

## Usage

Just like any other `Makie.jl` backend, you can simply `using TaichiMakie` and then do plots.

```julia
using TaichiMakie

fig = Figure(resolution = (600, 600))
ax = Axis(fig[1, 1], xlabel = "x", ylabel = "y")
lines!(ax, 1:10, 1:10)
save("test.png", fig)
```

## Gallery

### Contour plot

![Contour plot](./examples/contour.png)

### Heatmap

![Heatmap](examples/heatmap.png)

### Histogram

![Histogram](examples/hist.png)

### Scatter plot

![Scatter](examples/scatter.png)

### Violin plot

![Violin](examples/violin.png)

### Layout

![Layout](examples/layout.png)

> This plot contains some bugs.

## Known Issues

- Taichi GGUI does not support the following features:
  - anti-aliasing
  - alpha
- Support for meshes is still erroneous
