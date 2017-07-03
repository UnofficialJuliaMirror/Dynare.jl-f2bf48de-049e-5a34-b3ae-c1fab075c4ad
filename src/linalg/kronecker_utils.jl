module Kronecker

import Base.convert

"""
    a_mul_kron_b!(c::AbstractVector, a::AbstractVecOrMat, b::AbstractMatrix, order::Int64)

Performs a*(b ⊗ b ⊗ ... ⊗ b). The solution is returned in matrix c. order indicates the number of occurences of b

We use vec(a*(b ⊗ b ⊗ ... ⊗ b)) = (b' ⊗ b' ⊗ ... ⊗ b' \otimes I)vec(a)

"""
function a_mul_kron_b!(c::AbstractMatrix, a::AbstractMatrix, b::AbstractMatrix, order::Int64, work::AbstractVector)
    ma, na = size(a)
    mb, nb = size(b)
    mc, nc = size(c)
    mborder = mb^order
    nborder = nb^order
    na == mborder || throw(DimensionMismatch("The number of columns of a, $na, doesn't match the number of rows of b, $mb, times order = $order"))
    mc == ma || throw(DimensionMismatch("The number of rows of c, $mc, doesn't match the number of rows of a, $ma"))
    nc == nborder || throw(DimensionMismatch("The number of columns of c, $nc, doesn't match the number of columns of b, $nb, times order = $order"))
 
    avec = vec(a)
    for q=0:order-1
        vavec = view(avec,1:ma*mb^(order-q)*nb^q)
        vwork = view(work,1:ma*mb^(order-q-1)*nb^(q+1))
        kron_mul_elem_t!(vwork,b,vavec,order-q-1,q,ma)
        if q < order - 1
            copy!(avec,vwork)
        end
    end
    vwork = view(work,1:ma*nborder)
    copy!(c,vwork)
end
    
function a_mul_kron_b!(c::AbstractMatrix, a::AbstractMatrix, b::AbstractMatrix, order::Int64)
    ma, na = size(a)
    mb, nb = size(b)
    mc, nc = size(c)
    mborder = mb^order
    nborder = nb^order
    na == mborder || throw(DimensionMismatch("The number of columns of a, $na, doesn't match the number of rows of b, $mb, times order = $order"))
    mc == ma || throw(DimensionMismatch("The number of rows of c, $mc, doesn't match the number of rows of a, $ma"))
    nc == nborder || throw(DimensionMismatch("The number of columns of c, $nc, doesn't match the number of columns of b, $nb, times order = $order"))
    mb == nb || throw(DimensionMismatch("B must be a square matrix"))
 
    avec = vec(a)
    cvec = vec(c)
    for q=0:order-1
        vavec = view(avec,1:ma*mb^(order-q)*nb^q)
        println(size(cvec))
        vcvec = view(cvec,1:ma*mb^(order-q-1)*nb^(q+1))
        kron_mul_elem_t!(vcvec,b,vavec,order-q-1,q,ma)
        if q < order - 1
            copy!(avec,vcvec)
        end
    end
end
    
"""
    a_mul_b_kron_c!(d::AbstractVecOrMat, a::AbstractVecOrMat, b::AbstractMatrix, c::AbstractMatrix, order::Int64)

Performs a*B*(c ⊗ c ⊗ ... ⊗ c). The solution is returned in matrix or vector d. order indicates the number of occurences of c. c must be a square matrix

We use vec(a*b*(c ⊗ c ⊗ ... ⊗ c)) = (c' ⊗ c' ⊗ ... ⊗ c' ⊗ a)vec(b)

"""
function a_mul_b_kron_c!(d::AbstractMatrix, a::AbstractMatrix, b::AbstractMatrix, c::AbstractMatrix, order::Int64)
    ma, na = size(a)
    mb, nb = size(b)
    mc, nc = size(c)
    md, nd = size(d)
    ma == na || throw(DimensionMismatch("a must be a square matrix"))
    mc == nc || throw(DimensionMismatch("c must be a square matrix"))
    na == mb || throw(DimensionMismatch("The number of columns of a, $(size(a,2)), doesn't match the number of rows of b, $(size(b,1))"))
    nb == mc^order || throw(DimensionMismatch("The number of columns of b, $(size(b,2)), doesn't match the number of rows of c, $(size(c,1)), times order, $order"))
    (ma == md && nc^order == nd) || throw(DimensionMismatch("Dimension mismatch for D: $(size(d)) while ($ma, $(nc^order)) was expected"))
    A_mul_B!(d,a,b)
    copy!(b,d)
    bvec = vec(b)
    dvec = vec(d)
    for q=0:order-1
        kron_mul_elem_t!(dvec,c,bvec,order-q-1,q,ma)
        if q < order - 1
            copy!(bvec,dvec)
        end
    end
end

"""
    function kron_at_kron_b_mul_c!(a::AbstractMatrix, order::Int64, b::AbstractMatrix, c::AbstractVector, w::AbstractVector)
computes d = (a^T ⊗ a^T ⊗ ... ⊗ a^T ⊗ b)c
""" 
function kron_at_kron_b_mul_c!(d::AbstractVector, a::AbstractMatrix, order::Int64, b::AbstractMatrix, c::AbstractVector)
    ma,na = size(a)
    mb,nb = size(b)
    maorder = ma^order
    naorder = na^order
    length(d) == maorder*nb  || throw(DimensionMismatch("The dimension of the vector, $(length(b)) doesn't correspond to order, ($p, $q)  and the dimension of the matrices a, $(size(a)), and b, $(size(b))"))
    d1 = convert(Matrix{Float64},reshape(d,nb,naorder))
    c1 = convert(Matrix{Float64},reshape(c,nb,maorder))
    A_mul_B!(d1,b,c1)
    copy!(c1,d1)
    for q = 0:order-1
        kron_mul_elem_t!(d,a,c,order-q-1,q,nb)
        if q < order - 1
            copy!(c,d)
        end
    end
end

convert(::Type{Array{Float64, 2}}, x::Base.ReshapedArray{Float64,2,SubArray{Float64,1,Array{Float64,1},Tuple{UnitRange{Int64}},true},Tuple{}}) = unsafe_wrap(Array,pointer(x.parent.parent,x.parent.indexes[1][1]),x.dims)


"""
    kron_mul_elem!(c::AbstractVector, a::AbstractMatrix, b::AbstractVector, p::Int64, q::Int64, m::Int64)

Performs (I_n^p \otimes a \otimes I_{m*n^q}) b, where n = size(a,2) and m, an arbitrary constant. The result is stored in c.
"""
function kron_mul_elem!(c::AbstractVector, a::AbstractMatrix, b::AbstractVector, p::Int64, q::Int64, m::Int64)
    ma, na = size(a)
    length(b) == m*ma^p*na^(q+1) || throw(DimensionMismatch("The dimension of vector b, $(length(b)) doesn't correspond to order, ($p, $q)  and the dimensions of the matrix, $(size(a))"))
    length(c) == m*ma^(p+1)*na^q || throw(DimensionMismatch("The dimension of the vector c, $(length(c)) doesn't correspond to order, ($p, $q)  and the dimensions of the matrix, $(size(a))"))


    @inbounds begin
        if m == 1 && p + q == 0
            # a*b
            A_mul_B!(c,a,b)
        elseif m == 1 && q == 0
            #  (I_n^p ⊗ a)*b = vec(a*[b_1 b_2 ... b_p])
            b = convert(Array{Float64,2},reshape(b,na,ma^p))
            c = convert(Array{Float64,2},reshape(c,ma,ma^p))
            A_mul_B!(c,a,b)
        elseif p == 0
            # (a ⊗ I_{m*n^q})*b = (b'*(a' ⊗ I_{m*n^q}))' = vec(reshape(b,m*n^q,n)*a')
            @time b = convert(Array{Float64,2},reshape(b,m*ma^p*na^q,na))
            @time c = convert(Array{Float64,2},reshape(c,m*ma^p*na^q,ma))
            @time A_mul_Bt!(c,b,a)
        else
            # (I_{n^p} ⊗ a ⊗ I_{m*n^q})*b = vec([(a ⊗ I_{m*n^q})*b_1 (a ⊗ I_{m*n^q})*b_2 ... (a ⊗ I_{m*n^q})*b_{n^p}])
            mnq = m*na^q
            mnq1 = mnq*na
            qrangeb = 1:mnq1
            mnq2 = mnq*ma
            qrangec = 1:mnq2
            for i=1:ma^p
                bi = convert(Array{Float64,2},reshape(view(b,qrangeb),m*na^q,na))
                ci = convert(Array{Float64,2},reshape(view(c,qrangec),m*na^q,ma))
                # (a ⊗ I_{m*n^q})*b = (b'*(a' ⊗ I_{m*n^q}))' = vec(reshape(b',m*n^q,n)*a')
                A_mul_Bt!(ci,bi,a)
                qrangeb += mnq1
                qrangec += mnq2
            end
        end
    end
end

"""
    kron_mul_elem_t!(p::Int64, q::Int64, m::Int64, a::AbstractMatrix, b::AbstractVector, c::AbstractVector)

Performs (I_n^p \otimes a' \otimes I_{m*n^q}) b, where n = size(a,2) and m, an arbitrary constant. The result is stored in c.
"""
function kron_mul_elem_t!(c::AbstractVector, a::AbstractMatrix, b::AbstractVector, p::Int64, q::Int64, m::Int64)
    ma, na = size(a)
    length(b) == m*ma^(p+1)*na^q || throw(DimensionMismatch("The dimension of vector b, $(length(b)) doesn't correspond to order, ($p, $q)  and the dimensions of the matrix, $(size(a))"))
    length(c) == m*ma^p*na^(q+1) || throw(DimensionMismatch("The dimension of the vector c, $(length(c)) doesn't correspond to order, ($p, $q)  and the dimensions of the matrix, $(size(a))"))

#    @inbounds begin
    begin
        if m == 1 && p + q == 0
            # a'*b
            At_mul_B!(c,a,b)
        elseif m == 1 && q == 0
            #  (I_n^p ⊗ a')*b = vec(a'*[b_1 b_2 ... b_p])
            b = convert(Array{Float64,2},reshape(b,ma,ma^p))
            c = convert(Array{Float64,2},reshape(c,na,ma^p))
            At_mul_B!(c,a,b)
        elseif p == 0
            # (a' ⊗ I_{m*n^q})*b = (b'*(a ⊗ I_{m*n^q}))' = vec(reshape(b,m*na^q,ma)*a)
            mnq = m*na^q
            b = convert(Array{Float64,2},reshape(b,mnq,ma))
            c = convert(Array{Float64,2},reshape(c,mnq,na))
            A_mul_B!(c,b,a)
        else
            # (I_{n^p} ⊗ a' ⊗ I_{m*n^q})*b = vec([(a' ⊗ I_{m*n^q})*b_1 (a' ⊗ I_{m*n^q})*b_2 ... (a' ⊗ I_{m*n^q})*b_{n^p}])
            mnq = m*na^q
            mnq1 = mnq*ma
            qrange1 = 1:mnq1
            mnq2 = mnq*na
            qrange2 = 1:mnq2
            for i=1:ma^p
                bi = convert(Array{Float64,2},reshape(view(b,qrange1),mnq,ma))
                ci = convert(Array{Float64,2},reshape(view(c,qrange2),mnq,na))
                # (a' ⊗ I_{m*n^q})*bi = (bi'*(a ⊗ I_{m*n^q}))' = vec(reshape(bi,m*n^q,n)*a)
                A_mul_B!(ci,bi,a)
                qrange1 += mnq1
                qrange2 += mnq2
            end
        end
    end
end

end
