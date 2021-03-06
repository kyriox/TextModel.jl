export EntModel, vectorize, id2token

type EntModel <: Model
    tokens::Dict{String,WeightedToken}
    config::TextConfig
end

function EntModel(model::DistModel, initial)
    tokens = Dict{String,WeightedToken}()
    nclasses = length(model.sizes)
    tokenID = 0
    maxent = log2(nclasses)

    for (token, tokendist) in model.tokens
        e = 0.0
        pop = initial * nclasses + sum(tokendist.dist)

        # @show tokendist, initial, nclasses, sum(tokendist.dist)
        for j in 1:nclasses
            pj = (tokendist.dist[j] + initial) / pop

            if pj > 0
                e -= pj * log2(pj)
            end
        end
        tokenID += 1
        tokens[token] = WeightedToken(tokenID, maxent - e)
    end

    EntModel(tokens, model.config)
end

function id2token(model::EntModel)
    m = Dict{UInt64,String}()
    for (token, term) in model.tokens
        m[term.id] = token
    end

    m
end

function vectorize(text::String, model::EntModel; corrector::Function=identity)
    bow = compute_bow(text, model.config)
    vec = Vector{WeightedToken}()
    sizehint!(vec, length(bow))

    for (token, freq) in bow
        term = try
            token = corrector(token)
            model.tokens[token]
        catch err
            continue
        end
        push!(vec, term)
    end

    sort!(vec, by=(x) -> x.id)
    VBOW(vec)
end
