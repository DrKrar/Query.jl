immutable EnumerableOrderby{T,S,KS<:Function,TKS} <: Enumerable
    source::S
    keySelector::KS
    descending::Bool
end

Base.iteratorsize{T,S,KS,TKS}(::Type{EnumerableOrderby{T,S,KS,TKS}}) = Base.iteratorsize(S)

Base.eltype{T,S,KS,TKS}(iter::EnumerableOrderby{T,S,KS,TKS}) = T

Base.eltype{T,S,KS,TKS}(iter::Type{EnumerableOrderby{T,S,KS,TKS}}) = T

Base.length{T,S,KS,TKS}(iter::EnumerableOrderby{T,S,KS,TKS}) = length(iter.source)

function orderby(source::Enumerable, f::Function, f_expr::Expr)
    T = eltype(source)
    TKS = Base.return_types(f, (T,))[1]

    KS = typeof(f)

    return EnumerableOrderby{T,typeof(source), KS,TKS}(source, f, false)
end

function orderby_descending(source::Enumerable, f::Function, f_expr::Expr)
    T = eltype(source)
    TKS = Base.return_types(f, (T,))[1]

    KS = typeof(f)

    return EnumerableOrderby{T,typeof(source),KS,TKS}(source, f, true)
end

function start{T,S,KS,TKS}(iter::EnumerableOrderby{T,S,KS,TKS})
    rows = Base.iteratorsize(typeof(iter))==Base.HasLength() ? length(iter) : 0

    elements = Array{T}(rows)

    if Base.iteratorsize(typeof(iter))==Base.HasLength()
        for i in enumerate(iter.source)
            elements[i[1]] = i[2]
        end        
    else
        for i in iter.source
            push!(elements, i)
        end
    end

    sort!(elements, by=iter.keySelector, rev=iter.descending)

    return elements, 1
end

function next{T,S,KS,TKS}(iter::EnumerableOrderby{T,S,KS,TKS}, state)
    elements = state[1]
    i = state[2]
    return elements[i], (elements, i+1)
end

done{T,S,KS,TKS}(f::EnumerableOrderby{T,S,KS,TKS}, state) = state[2] > length(state[1])

immutable EnumerableThenBy{T,S,KS<:Function,TKS} <: Enumerable
    source::S
    keySelector::KS
    descending::Bool
end

Base.eltype{T,S,KS,TKS}(iter::EnumerableThenBy{T,S,KS,TKS}) = T

Base.eltype{T,S,KS,TKS}(iter::Type{EnumerableThenBy{T,S,KS,TKS}}) = T

Base.length{T,S,KS,TKS}(iter::EnumerableThenBy{T,S,KS,TKS}) = length(iter.source)

function thenby(source::Enumerable, f::Function, f_expr::Expr)
    T = eltype(source)
    TKS = Base.return_types(f, (T,))[1]
    KS = typeof(f)
    return EnumerableThenBy{T,typeof(source),KS,TKS}(source, f, false)
end

function thenby_descending(source::Enumerable, f::Function, f_expr::Expr)
    T = eltype(source)
    TKS = Base.return_types(f, (T,))[1]
    KS = typeof(f)
    return EnumerableThenBy{T,typeof(source),KS,TKS}(source, f, true)
end

# TODO This should be changed to a lazy implementation
function start{T,S,KS,TKS}(iter::EnumerableThenBy{T,S,KS,TKS})
    # Find start of ordering sequence
    source = iter.source
    keySelectors = [source.keySelector,iter.keySelector]
    directions = [source.descending, iter.descending]
    while !isa(source, EnumerableOrderby)
        source = source.source
        insert!(keySelectors,1,source.keySelector)
        insert!(directions,1,source.descending)
    end
    keySelector = element->[i(element) for i in keySelectors]

    lt = (t1,t2) -> begin
        n1, n2 = length(t1), length(t2)
        for i = 1:min(n1, n2)
            a, b = t1[i], t2[i]
            descending = directions[i]
            if !isequal(a, b)
                return descending ? !isless(a, b) : isless(a, b)
            end
        end
        return n1 < n2
    end

    rows = Base.iteratorsize(typeof(iter))==Base.HasLength() ? length(iter) : 0

    elements = Array{T}(rows)

    if Base.iteratorsize(typeof(iter))==Base.HasLength()
        for i in enumerate(iter.source)
            elements[i[1]] = i[2]
        end        
    else
        for i in iter.source
            push!(elements, i)
        end
    end

    sort!(elements, by=keySelector, lt=lt)

    return elements, 1
end

function next{T,S,KS,TKS}(iter::EnumerableThenBy{T,S,KS,TKS}, state)
    elements = state[1]
    i = state[2]
    return elements[i], (elements, i+1)
end

done{T,S,KS,TKS}(f::EnumerableThenBy{T,S,KS,TKS}, state) = state[2] > length(state[1])
