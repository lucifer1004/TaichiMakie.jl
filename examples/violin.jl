using TaichiMakie

xs = rand(1:3, 1000)
ys = randn(1000)

save(joinpath(@__DIR__, "violin.png"), violin(xs, ys))
