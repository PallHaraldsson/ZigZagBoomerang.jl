eventtime(x) = x[1]
eventposition(x) = x[2]

#Poisson rates which determine the first reflection time
λ(∇ϕ, x, θ, F::ZigZag1d) = pos(θ*∇ϕ(x))
λ(∇ϕ, x, θ, B::Boomerang1d) = pos(θ*(∇ϕ(x) - (x - B.μ)))

# affine bounds for Zig-Zag
λ_bar(x, θ, c, ::ZigZag1d) = pos(c + θ*x)

# constant bound for Boomerang1d with global bounded |∇ϕ(x)|
# suppose |∇ϕ(x, :Boomerang1d)| ≤ C. Then λ(x(t),θ(t)) ≤ C*sqrt(x(0)^2 + θ(0)^2)
λ_bar(x, θ, c, B::Boomerang1d) = sqrt(θ^2 + (x - B.μ)^2)*c #Global bound

# waiting times
ab(x, θ, c, ::ZigZag1d) = (c + θ*x, θ^2)
ab(x, θ, c, B::Boomerang1d) = (sqrt(θ^2 + (x - B.μ)^2)*c, zero(x))

# waiting_time
waiting_time_ref(::ZigZag1d) = Inf
waiting_time_ref(B::Boomerang1d) = poisson_time(B.λref, 0.0, rand())


# Algorithm for one dimensional pdmp (ZigZag1d or Boomerang)
"""
    pdmp(∇ϕ, x, θ, T, Flow::ContinuousDynamics; adapt=true,  factor=2.0)

Run a piecewise deterministic process from location and velocity `x, θ` until time
`T`. `c` is a tuning parameter for the upper bound of the Poisson rate.
If `adapt = false`, `c = c*factor` is tried, otherwise an error is thrown.

Returns vector of tuples `(t, x, θ)` (time, location, velocity) of
direction change events.
"""
function pdmp(∇ϕ, x, θ, T, c, Flow::ContinuousDynamics; adapt=false, factor=2.0)
    scaleT = Flow isa Boomerang1d ? 1.25 : 1.0
    T = T*scaleT
    t = zero(T)
    Ξ = [(zero(x), x, θ)]
    τref = waiting_time_ref(Flow)
    num = acc = 0
    τ =  poisson_time(ab(x, θ, c, Flow)..., rand())
    while t < T
        if τref < τ
            t, x, θ = move_forward(τref, t, x, θ, Flow)
            θ = randn()
            τref = waiting_time_ref(Flow)
            τ =  poisson_time(ab(x, θ, c, Flow)..., rand())
            push!(Ξ, (t, x, θ))
        else
            t, x, θ = move_forward(τ, t, x, θ, Flow)
            τref -= τ
            τ = poisson_time(ab(x, θ, c, Flow)..., rand())
            l, lb = λ(∇ϕ, x, θ, Flow), λ_bar(x, θ, c, Flow)
            num += 1
            if rand()*lb < l
                acc += 1
                if l >= lb
                    !adapt && error("Tuning parameter `c` too small.")
                    c *= factor
                end
                θ = -θ  # In multi dimensions the change of velocity is different:
                        # reflection symmetric on the normal vector of the contour
                push!(Ξ, (t, x, θ))
            end
        end
    end
    return Ξ, acc/num
end
