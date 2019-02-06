#  Copyright 2017, Iain Dunning, Joey Huchette, Miles Lubin, and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Returns the block expression inside a :let that holds the code to be run.
# The other block (not returned) is for declaring variables in the scope of the
# let.
function let_code_block(ex::Expr)
    @assert isexpr(ex, :let)
    @static if VERSION >= v"0.7-"
        return ex.args[2]
    else
        return ex.args[1]
    end
end

# generates code which converts an expression into a NodeData array (tape)
# parent is the index of the parent expression
# values is the name of the list of constants which appear in the expression

function JuMP.parseNLExpr_runtime(m::StructuredModel, x::Number, tape, parent, values)
    push!(values, x)
    push!(tape, NodeData(VALUE, length(values), parent))
    nothing
end

function JuMP.parseNLExpr_runtime(m::StructuredModel, x::StructuredVariableRef, tape, parent, values)
    # if owner_model(x) !== m
    #     error("Variable in nonlinear expression does not belong to the " *
    #           "corresponding model")
    # end
    # push!(tape, NodeData(MOIVARIABLE, x.index.value, parent))
    push!(tape, NodeData(MOIVARIABLE, x.idx , parent))
    nothing
end

function JuMP.parseNLExpr_runtime(m::StructuredModel, x::JuMP.NonlinearExpression, tape, parent, values)
    push!(tape, NodeData(SUBEXPRESSION, x.index, parent))
    nothing
end

function JuMP.parseNLExpr_runtime(m::StructuredModel, x::JuMP.NonlinearParameter, tape, parent, values)
    push!(tape, NodeData(PARAMETER, x.index, parent))
    nothing
end

function JuMP.parseNLExpr_runtime(m::StructuredModel, x::AbstractArray, tape, parent, values)
    error("Unexpected array $x in nonlinear expression. Nonlinear expressions may contain only scalar expressions.")
end

function JuMP.parseNLExpr_runtime(m::StructuredModel, x::JuMP.GenericQuadExpr, tape, parent, values)
    error("Unexpected quadratic expression $x in nonlinear expression. " *
          "Quadratic expressions (e.g., created using @expression) and " *
          "nonlinear expression cannot be mixed.")
end

function JuMP.parseNLExpr_runtime(m::StructuredModel, x, tape, parent, values)
    error("Unexpected object $x $(typeof(x)) in nonlinear expression.")
end

# Construct a NonlinearExprData from a Julia expression.
# VariableRef objects should be spliced into the expression.
function JuMP.NonlinearExprData(m::StructuredModel, ex::Expr)
    initNLP(m)
    checkexpr(m,ex)
    nd, values = Derivatives.expr_to_nodedata(ex,m.nlp_data.user_operators)
    return NonlinearExprData(nd, values)
end
JuMP.NonlinearExprData(m::StructuredModel, ex) = NonlinearExprData(m, :($ex + 0))

# Error if:
# 1) Unexpected expression
# 2) VariableRef doesn't match the model
function JuMP.checkexpr(m::StructuredModel, ex::Expr)
    if ex.head == :ref # if we have x[1] already in there, something is wrong
        error("Unrecognized expression $ex. JuMP variable objects and input coefficients should be spliced directly into expressions.")
    end
    for e in ex.args
        checkexpr(m, e)
    end
    return
end
function JuMP.checkexpr(m::StructuredModel, v::VariableRef)
    owner_model(v) === m || error("Variable $v does not belong to this model.")
    return
end
JuMP.checkexpr(m::StructuredModel, ex) = nothing
