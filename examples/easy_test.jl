import MPI # put this first!
using StochJuMP, JuMP

MPI.init()

m = StochasticModel()

@defVar(m, 0 <= x <= 1)
@defVar(m, 0 <= y <= 1)

@addConstraint(m, x + y == 1)
@setObjective(m, Min, x*x + y)

numScen = 2

bl = StochasticBlock(m, numScen)
@defVar(bl, w >= 0)
@addConstraint(bl, w - x - y <= 1)
setObjective(bl, :Min, w)

StochJuMP.pips_solve(m)
