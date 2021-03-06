## Reference: https://github.com/SciML/MethodOfLines.jl

using ModelingToolkit, MethodOfLines, LinearAlgebra, OrdinaryDiffEq, DomainSets
using ModelingToolkit: Differential
import DifferentialEquations

# Variables, parameters, and derivatives
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

# Discretization parameters 
dt = 0.1            # Value to change! It has to be the same as the dt in pinn_spm.jl.
dr = dt

order = 2

# Analytic solution for boundary conditions

# Equation
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

# Space and time domains
domains = [
    t ∈ Interval(0.0, 1.0),
    r ∈ Interval(0.0, 1.0),
]

# PDE system
@named pdesys = PDESystem(eqs, bcs, domains, [t,r], [c_sp(t,r), c_sn(t,r)])

# Method of lines discretization
discretization = MOLFiniteDifference([t=>dt, r=>dr]; approx_order = order)
prob = ModelingToolkit.discretize(pdesys, discretization)

# Solution of the ODE system
sol = solve(prob,Tsit5())

# Extract solutions of concentrations
iter = trunc(Int, (1/dt+1))

sol_c_sn_dt = []
sol_c_sp_dt = []
for i in (1:iter)
    append!(sol_c_sn_dt, [sol[iter*(i-1)+1:iter*(i)]])
    append!(sol_c_sp_dt, [sol[iter^2+(iter*(i-1)+1):iter^2+iter*(i)]])
    i=i+1
end


