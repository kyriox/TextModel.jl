#  Copyright 2016, 2017 Eric S. Tellez <eric.tellez@infotec.mx>
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

export VBOW, cosine_distance, angle_distance, cosine

import Base: +, *, ==, dot, length

struct WeightedToken
    id::UInt64
    weight::Float64
end

mutable struct VBOW
    tokens::Vector{WeightedToken}
    invnorm::Float64
end

function VBOW(tokens::Vector{WeightedToken})
    VBOW(tokens, -1.0)  # valid invnorm values are greater or equal to zero
end

function invnorm(bow::VBOW)
    if bow.invnorm < 0.0
        xnorm::Float64 = 0.0
        @fastmath @inbounds @simd for i = 1:length(bow.tokens)
            xnorm += bow.tokens[i].weight ^ 2
        end

        if length(bow.tokens) > 0
            @fastmath bow.invnorm = 1/sqrt(xnorm)
        else
            bow.invnorm = 0.0
        end
    end

    bow.invnorm
end

function VBOW(bow::Vector{Tuple{I, F}}) where {I <: Any, F <: Real}
    M = Vector{WeightedToken}(length(bow))
    i = 1
    if I <: Integer
        for (key, value) in bow
            M[i] = WeightedToken(convert(UInt64, key), convert(Float64, value))
            i+=1
        end
    else
        for (key, value) in bow
            M[i] = WeightedToken(hash(key), convert(Float64, value))
            i+=1
        end
    end

    sort!(M, by=(x)->x.id)
    VBOW(M)
end

function VBOW(bow::Dict{I, F}) where {I <: Any, F <: Real}
    M = Vector{WeightedToken}(length(bow))
    i = 1
    if I <: Integer
        for (key, value) in bow
            M[i] = WeightedToken(convert(UInt64, key), convert(Float64, value))
            i+=1
        end
    else
        for (key, value) in bow
            M[i] = WeightedToken(hash(key), convert(Float64, value))
            i+=1
        end
    end

    sort!(M, by=(x)->x.id)
    VBOW(M)
end

length(a::VBOW) = length(a.tokens)

function cosine_distance(a::VBOW, b::VBOW)::Float64
    return 1.0 - cosine(a, b)
end

function angle_distance(a::VBOW, b::VBOW)
    c = cosine(a, b)
    c = max(c, -1)
    c = min(c, 1)
    return acos(c)
end

function dot(a::VBOW, b::VBOW)::Float64
    n1=length(a.tokens)
    n2=length(b.tokens)
    # (n1 == 0 || n2 == 0) && return 0.0

    sum::Float64 = 0.0
    i = 1; j = 1

    @fastmath @inbounds while i <= n1 && j <= n2
        c = cmp(a.tokens[i].id, b.tokens[j].id)
        if c == 0
            sum += a.tokens[i].weight * b.tokens[j].weight
            i += 1
            j += 1
        elseif c < 0
            i += 1
        else
            j += 1
        end
    end

    return sum
end

function cosine(a::VBOW, b::VBOW)::Float64
    return dot(a, b) * invnorm(a) * invnorm(b)
end


"""
   vbow1 + vbow2

   Computes the sum of two VBOW vectors
"""
function +(a::VBOW, b::VBOW)
    vec = Vector{WeightedToken}()
    n1=length(a.tokens)
    n2=length(b.tokens)
    sizehint!(vec, max(n1, n2))

    i = 1; j = 1
    @fastmath @inbounds while i <= n1 && j <= n2
        c = cmp(a.tokens[i].id, b.tokens[j].id)
        if c == 0
            push!(vec, WeightedToken(a.tokens[i].id, a.tokens[i].weight + b.tokens[j].weight))
            i += 1
            j += 1
        elseif c < 0
            push!(vec, WeightedToken(a.tokens[i].id, a.tokens[i].weight))
            i += 1
        else
            push!(vec, WeightedToken(b.tokens[j].id, b.tokens[j].weight))
            j += 1
        end
    end

    return VBOW(vec)
end

#Base::+(a::VBOW, b::VBOW) = sum_vbow

"""
   vbow1 * vbow2

   Point to point product (Hadamard product)
"""
function *(a::VBOW, b::VBOW)
    vec = Vector{WeightedToken}()
    n1=length(a.tokens)
    n2=length(b.tokens)
    sizehint!(vec, min(n1, n2))

    i = 1; j = 1
    @fastmath @inbounds while i <= n1 && j <= n2
        c = cmp(a.tokens[i].id, b.tokens[j].id)
        if c == 0
            push!(vec, WeightedToken(a.tokens[i].id, a.tokens[i].weight * b.tokens[j].weight))
            i += 1
            j += 1
        elseif c < 0
            i += 1
        else
            j += 1
        end
    end

    return VBOW(vec)
end

function ==(a::WeightedToken, b::WeightedToken)
    return a.id == b.id && a.weight == b.weight
end

function ==(a::VBOW, b::VBOW)
    if length(a.tokens) == length(b.tokens)
        for i in 1:length(a.tokens)
            if a.tokens[i] != b.tokens[i]
                return false
            end
        end

        return true
    else
        return false
    end
end
