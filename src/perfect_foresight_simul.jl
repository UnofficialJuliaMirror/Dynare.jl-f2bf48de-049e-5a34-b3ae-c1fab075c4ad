# Computes the perfect foresight simulation of a model for periods 1...T
# - endopath is a matrix with time in columns (T+2) and with endogenous variables in rows
#   first and last column are respectively initial and terminal conditions
#   the other columns are the guess values, and will be replaced by the simulated values
# - exopath is a matrix with time in columns (T) and with exogenous variables in rows

require("suitesparse")

function perfect_foresight_simul!(m::Model, endopath::Matrix{Float64}, exopath::Matrix{Float64}, calib::Dict{Symbol, Float64})
    maxit = 500
    tolerance = 1e-6

    T = size(endopath, 2) - 2
    @assert size(endopath, 1) == m.n_endo
    @assert size(exopath, 2) == T
    @assert size(exopath, 1) == m.n_exo

    p = calib2vec(m, calib)

    A = spzeros(T*m.n_endo, T*m.n_endo)
    res = zeros(T*m.n_endo)

    Y = vec(endopath)
    
    for iter = 1:maxit

        i_cols = [m.zeta_back_mixed; m.n_endo+(1:m.n_endo); 2*m.n_endo+m.zeta_fwrd_mixed]
        i_rows = 1:m.n_endo
        
        for it = 2:T+1
            (d1, jacob) = m.dynamic_mf(Y[i_cols], exopath[1:m.n_exo, it-1], p)

            if it == T+1 && it == 2
                idx = m.n_back_mixed+(1:m.n_endo)
            elseif it == T+1
                idx = 1:(m.n_back_mixed+m.n_endo)
            elseif it == 2
                idx = m.n_back_mixed+1:(m.n_endo+m.n_fwrd_mixed)
            else
                idx = 1:(m.n_back_mixed+m.n_endo+m.n_fwrd_mixed)
            end

            A[i_rows,i_cols[idx]-m.n_endo] = jacob[:, idx]

            res[i_rows] = d1
        
            i_rows += m.n_endo
            i_cols += m.n_endo
        end

        err = max(abs(res))

        if err < tolerance
            endopath = reshape(Y, m.n_endo, T+2)
            return
        end

        Y[m.n_endo + (1:T*m.n_endo)] += -A\res
    end
    
    error("Convergence failed")
end
