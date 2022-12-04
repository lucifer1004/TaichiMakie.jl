using TaichiMakie

f = Figure()
sc = Screen(f.scene; visible = true)
ax = Axis(f[1, 1], xlabel = "x", ylabel = "y")
xs = Observable(1:10)
ys = Observable(rand(10))
lines!(ax, xs, ys)

for i in 1:100
    display(sc)
    ys[] = rand(10)
    sleep(0.05)
end
