using TaichiMakie

f = Figure()
ax = Axis3(f[1, 1])
x = rand(20)
y = rand(20)
z = rand(20)
scatter!(ax, x, y, z; markersize = 10)
save(joinpath(@__DIR__, "scatter.png"), f)
