using TaichiMakie
using Makie.FileIO

f = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98),
           resolution = (1000, 700))
ga = f[1, 1] = GridLayout()
gb = f[2, 1] = GridLayout()
gcd = f[1:2, 2] = GridLayout()
gc = gcd[1, 1] = GridLayout()
gd = gcd[2, 1] = GridLayout()
axtop = Axis(ga[1, 1])
axmain = Axis(ga[2, 1], xlabel = "before", ylabel = "after")
axright = Axis(ga[2, 2])

linkyaxes!(axmain, axright)
linkxaxes!(axmain, axtop)

labels = ["treatment", "placebo", "control"]
data = randn(3, 100, 2) .+ [1, 3, 5]

for (label, col) in zip(labels, eachslice(data, dims = 1))
    scatter!(axmain, col, label = label)
    density!(axtop, col[:, 1])
    density!(axright, col[:, 2], direction = :y)
end

ylims!(axtop, low = 0)
xlims!(axright, low = 0)

axmain.xticks = 0:3:9
axtop.xticks = 0:3:9

leg = Legend(ga[1, 2], axmain)

hidedecorations!(axtop, grid = false)
hidedecorations!(axright, grid = false)
leg.tellheight = true

colgap!(ga, 10)
rowgap!(ga, 10)

Label(ga[1, 1:2, Top()], "Stimulus ratings", valign = :bottom,
      font = "TeX Gyre Heros Bold",
      padding = (0, 0, 5, 0))

xs = LinRange(0.5, 6, 50)
ys = LinRange(0.5, 6, 50)
data1 = [sin(x^1.5) * cos(y^0.5) for x in xs, y in ys] .+ 0.1 .* randn.()
data2 = [sin(x^0.8) * cos(y^1.5) for x in xs, y in ys] .+ 0.1 .* randn.()

ax1, hm = contourf(gb[1, 1], xs, ys, data1,
                   levels = 6)
ax1.title = "Histological analysis"
contour!(ax1, xs, ys, data1, levels = 5, color = :black)
hidexdecorations!(ax1)

ax2, hm2 = contourf(gb[2, 1], xs, ys, data2,
                    levels = 6)
contour!(ax2, xs, ys, data2, levels = 5, color = :black)

cb = Colorbar(gb[1:2, 2], hm, label = "cell group")
low, high = extrema(data1)
edges = range(low, high, length = 7)
centers = (edges[1:6] .+ edges[2:7]) .* 0.5
cb.ticks = (centers, string.(1:6))

cb.alignmode = Mixed(right = 0)

colgap!(gb, 10)
rowgap!(gb, 10)

brain = load(assetpath("brain.stl"))

ax3d = Axis3(gc[1, 1], title = "Brain activation")
m = mesh!(ax3d,
          brain,
          color = [tri[1][2] for tri in brain for i in 1:3],
          colormap = Reverse(:magma))
Colorbar(gc[1, 2], m, label = "BOLD level")

axs = [Axis(gd[row, col]) for row in 1:3, col in 1:2]
hidedecorations!.(axs, grid = false, label = false)

for row in 1:3, col in 1:2
    xrange = col == 1 ? (0:0.1:(6pi)) : (0:0.1:(10pi))

    eeg = [sum(sin(pi * rand() + k * x) / k for k in 1:10)
           for x in xrange] .+ 0.1 .* randn.()

    lines!(axs[row, col], eeg, color = (:black, 0.5))
end

axs[3, 1].xlabel = "Day 1"
axs[3, 2].xlabel = "Day 2"

Label(gd[1, :, Top()], "EEG traces", valign = :bottom,
      font = "TeX Gyre Heros Bold",
      padding = (0, 0, 5, 0))

rowgap!(gd, 10)
colgap!(gd, 10)

for (i, label) in enumerate(["sleep", "awake", "test"])
    Box(gd[i, 3], color = :gray90)
    Label(gd[i, 3], label, rotation = pi / 2, tellheight = false)
end

colgap!(gd, 2, 0)

n_day_1 = length(0:0.1:(6pi))
n_day_2 = length(0:0.1:(10pi))

colsize!(gd, 1, Auto(n_day_1))
colsize!(gd, 2, Auto(n_day_2))

for (label, layout) in zip(["A", "B", "C", "D"], [ga, gb, gc, gd])
    Label(layout[1, 1, TopLeft()], label,
          textsize = 26,
          font = "TeX Gyre Heros Bold",
          padding = (0, 5, 5, 0),
          halign = :right)
end

colsize!(f.layout, 1, Auto(0.5))

rowsize!(gcd, 1, Auto(1.5))

save(joinpath(@__DIR__, "layout.png"), f)
