using Test
using Statistics
using Random
using LinearAlgebra
using ZigZagBoomerang
using ZigZagBoomerang: poisson_time

Random.seed!(1)
sep(x) = first.(x), last.(x)

# testing poisson time sampler

a, b = 1.1, 0.0
n = 5000
Λ0(a, b, T) = a*T + b*(T)^2/2
P(a, b, T) = 1 - exp(-Λ0(a, b, T))
T = 0.7

for (a, b, pt) in ((1.1, 0.0, NaN), (1.1, 0.3, NaN), (0.0, 0.3, NaN), (1.1, -0.5, NaN),
    (-0.5, 1, P(0, 1, T-0.5)), (-1, -2, 0.0))
    p = mean(poisson_time(a, b, rand()) < T for i in 1:n)
    if isnan(pt)
        pt = P(a, b, T)
    end
#    @show p, pt
    @test abs(p - pt) < 2/sqrt(n)
end


# negative log-density with respect to Lebesgue
# ϕ(x) =  (x - π)^2/2 # not needed

# gradient of ϕ(x)
∇ϕ(x) = x - π
∇ϕhat(x) = x - π + 0.1(rand()-0.5)


x0, θ0 = 0.01, -1.5
T = 6000.0
out1, _ = ZigZagBoomerang.pdmp(∇ϕhat, x0, θ0, T, 10.0, ZigZag1d())
B = Boomerang1d(2.0, 0.5)
out2, _ = ZigZagBoomerang.pdmp(∇ϕhat, x0, θ0, T, 4.0, B)

@testset "ZigZag1d" begin
    @test T/10 < length(out1) < T*10
    est = 1/T*sum((eventposition.(out1)[1:end-1] + eventposition.(out1)[2:end])/2 .* diff(eventtime.(out1)))
    @test abs(est-pi) < 2/sqrt(length(out1))
    dt = 0.01
    traj = ZigZagBoomerang.discretization(out1, ZigZag1d(), dt)
    est = mean(traj.x)
    @test abs(est-pi) < 2/sqrt(length(out1))
    c = 10.0
    a,b = ZigZagBoomerang.ab(x0, θ0, c, ZigZag1d())
    @test ZigZagBoomerang.λ_bar(x0 + 0.3*θ0, θ0, c, ZigZag1d()) ≈ a + b*0.3
    a,b = ZigZagBoomerang.ab(x0, -θ0, c, ZigZag1d())
    @test ZigZagBoomerang.λ_bar(x0 - 0.3*θ0, -θ0, c, ZigZag1d()) ≈ a + b*0.3

end

@testset "Boomerang1d" begin
    @test T/10 < length(out2) < T*10
    dt = 0.01
    traj = ZigZagBoomerang.discretization(out2, B, dt)
    est = mean(traj.x)
    @test abs(est-pi) < 3/sqrt(length(out2))
    c = 10.0
    τ = 0.3
    a, b = ZigZagBoomerang.ab(x0, θ0, c, B)
    _, x, θ = ZigZagBoomerang.move_forward(τ, 0.0, x0, θ0, B)
    @test ZigZagBoomerang.λ_bar(x, θ, c, B) ≈ a + b*τ

end


# Local ZigZag
using SparseArrays
d = 8
S = I + 0.5sprandn(d, d, 0.1)
Γ = S*S'

∇ϕ(x, i, Γ) = ZigZagBoomerang.idot(Γ, i, x) # sparse computation


@testset "LocalZigZag" begin

t0 = 0.0
x0 = rand(d)
θ0 = rand([-1.0, 1.0], d)


c = .5*[norm(Γ[:, i], 2) for i in 1:d]

Z = LocalZigZag(0.9Γ, x0*0)
T = 1000.0

trace, _, acc = @time pdmp(∇ϕ, t0, x0, θ0, T, c, Z, Γ)
dt = 0.5
ts, xs = sep(collect(discretize(trace, dt)))

@show acc[1]/acc[2]

G = [i => rowvals(Z.Γ)[nzrange(Z.Γ, i)] for i in eachindex(θ0)]
for i in 1:d
    a, b = ZigZagBoomerang.ab(G, i, x0, θ0, c, Z)
    @test ZigZagBoomerang.λ_bar(G, i, x0 + 0.3*θ0, θ0, c, Z) ≈ ZigZagBoomerang.pos(a + b*0.3)
end

@test mean(abs.(cov(xs) - inv(Matrix(Γ)))) < 2.5/sqrt(T)
#display(round.(cov(xs) - inv(Matrix(Γ)), digits=3))
#display(round.(cov(xs), digits=3))
#display(round.( inv(Matrix(Γ)), digits=3))
end

@testset "LocalZigZag (independent)" begin

t0 = 0.0
x0 = rand(d)
θ0 = rand([-1.0, 1.0], d)


c = 10.0*[norm(Γ[:, i], 2) for i in 1:d]
Γ0 = sparse(I, d, d)
Z = LocalZigZag(Γ0, x0*0)

T = 1000.0

trace, _, acc = @time pdmp(∇ϕ, t0, x0, θ0, T, c, Z, Γ)
dt = 0.5
ts, xs = sep(collect(discretize(trace, dt)))

@show acc[1]/acc[2]

G0 = [i => rowvals(Z.Γ)[nzrange(Z.Γ, i)] for i in eachindex(θ0)]
for i in 1:d
    a, b = ZigZagBoomerang.ab(G0, i, x0, θ0, c, Z)
    @test ZigZagBoomerang.λ_bar(G0, i, x0 + 0.3*θ0, θ0, c, Z) ≈ ZigZagBoomerang.pos(a + b*0.3)
end

@test mean(abs.(cov(xs) - inv(Matrix(Γ)))) < 2.5/sqrt(T)
end
