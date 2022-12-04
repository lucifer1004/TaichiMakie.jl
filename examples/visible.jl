using TaichiMakie

f = Figure()
sc = Screen(f.scene; visible = true)
ax = Axis3(f[1, 1])
xs = rand(100)
ys = rand(100)
zs = Observable(rand(100))
scatter!(ax, xs, ys, zs, color = 1:100)

for i in 1:10
    display(sc)
    zs[] = rand(100)
    sleep(0.05)
end

TaichiMakie.destroy!(sc)
