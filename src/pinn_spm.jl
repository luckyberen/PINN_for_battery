# Reference: https://neuralpde.sciml.ai/stable/pinn/system/
#            Marquis, S. G., Sulzer, V., Timms, R., Please, C. P., & Chapman, S. J. (2019). An asymptotic derivation of a single particle model with electrolyte. arXiv [physics.chem-ph]. Opgehaal van http://arxiv.org/abs/1905.12553

using NeuralPDE, Flux, ModelingToolkit, GalacticOptim, Optim, DiffEqFlux
using Quadrature,Cubature,Plots
import ModelingToolkit: Interval, infimum, supremum

# Setting Parameters for PINN before Running:
max_iters = 10000   # number of iterations
n_dim = 15         # dimension of layers
dt = 0.1           # discretization. Here dr = dt
# End Setting


@parameters t, r
@variables c_sp(..), c_sn(..)
Dt = Differential(t)
Dr = Differential(r)

# Constants
C_p = 0.0442
C_n = 0.1134
a_n = 1.8
a_p = 1.5
y_n = 1
y_p = 2.0501
L_p = 0.4444
L_n = 0.4444
I = 1.0



# Equations
eqs = [
    C_p*Dt(c_sp(t,r)) ~ (1/(r)^2)*Dr(((r)^2)*Dr(c_sp(t,r))),
    C_n*Dt(c_sn(t,r)) ~ (1/(r)^2)*Dr(((r)^2)*Dr(c_sn(t,r)))
]

# Initial and boundary conditions
bcs = [
    Dr(c_sp(t,0)) ~ 0,
    Dr(c_sn(t,0)) ~ 0,
    ((a_p*y_p)/(C_p))*Dr(c_sp(t,1)) ~ I/(L_p),
    ((a_n*y_n)/(C_n))*Dr(c_sn(t,1)) ~ -I/(L_n), 
    c_sp(0,r) ~ 0.6,
    c_sn(0,r) ~ 0.8
]


# Domains
domains = [
    t ∈ Interval(0.0, 1.0),
    r ∈ Interval(0.0, 1.0),
]


# Neural network
input_ = length(domains)
n = n_dim
chain = [FastChain(FastDense(input_, n, Flux.σ), FastDense(n,n,Flux.σ), FastDense(n,1)) for _ in 1:2]
initθ = map(c -> Float64.(c), DiffEqFlux.initial_params.(chain))

_strategy = QuadratureTraining()
discretization = PhysicsInformedNN(chain, _strategy, init_params=initθ)

@named pde_system = PDESystem(eqs,bcs, domains, [t,r], [c_sp(t,r), c_sn(t,r)])
prob = discretize(pde_system, discretization)
sys_prob = symbolic_discretize(pde_system, discretization)


# pde_inner_loss_functions = prob.f.f.loss_function.pde_loss_function.pde_loss_functions.contents
# bcs_inner_loss_functions = prob.f.f.loss_function.bcs_loss_function.bc_loss_functions.contents

cb = function (p,l)
    println("Current loss: ", l)
    # println("pde_losses: ", map(l_ -> l_(p), pde_inner_loss_functions))
    # println("bcs_losses: ", map(l_ -> l_(p), bcs_inner_loss_functions))
    return false
end

res = GalacticOptim.solve(prob,BFGS(); cb = cb, maxiters=max_iters)

phi = discretization.phi


# Discretization

ts,rs = [infimum(d.domain):dt:supremum(d.domain) for d in domains]
x_axis = collect(ts)

minimizers_=[]
append!(minimizers_, [res.minimizer[1:trunc(Int,size(res.minimizer)[1]/2)]])
append!(minimizers_, [res.minimizer[trunc(Int,size(res.minimizer)[1]/2+1):size(res.minimizer)[1]]])

c_sp_predict  = [phi[1]([t,r],minimizers_[1])[1] for t in ts  for r in rs]
c_sn_predict  = [phi[2]([t,r],minimizers_[2])[1] for t in ts  for r in rs]

# Extract dt and dr from two prediction variables

iter = trunc(Int, (1/dt+1))

pred_c_sp_row = []
pred_c_sn_row = []
for j in (1:iter)
    for k in (1:iter)
        append!(pred_c_sp_row, c_sp_predict[j+iter*(k-1)])
        append!(pred_c_sn_row, c_sn_predict[j+iter*(k-1)])
        k = k+1
    end
    j = j+1
end

pred_c_sp_dt = []
pred_c_sn_dt = []
for i in (1:iter)
    append!(pred_c_sp_dt, [pred_c_sp_row[iter*(i-1)+1:iter*(i)]])
    append!(pred_c_sn_dt, [pred_c_sn_row[iter*(i-1)+1:iter*(i)]])
    i=i+1
end

pred_c_sp_dr = []
pred_c_sn_dr = []
for m in (1:iter)
    append!(pred_c_sp_dr, [c_sp_predict[iter*(m-1)+1:iter*(m)]])
    append!(pred_c_sn_dr, [c_sn_predict[iter*(m-1)+1:iter*(m)]])
    m=m+1
end







