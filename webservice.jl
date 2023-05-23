using Oxygen, HTTP, SimilaritySearch, SimSearchManifoldLearning

include("src/create-indexes.jl")

X = load_or_create_indexes()

@post "/search/name" function (req)
    params = Oxygen.json(req)
    k = params["k"]
    q = params["q"]
    search_packages(X.D, X.nameidx, q, k)
end

@post "/search" function (req)
    params = Oxygen.json(req)
    k = params["k"]
    q = params["q"]

    Rdesc = KnnResult(10k)
    Rreadme = KnnResult(10k)
    wdesc = 0.66666f0
    wreadme = 0.33333f0

    res = KnnResult(10k)
    search(X.nameidx, q, res)
    C = Dict{UInt32,Float32}(p.id => p.weight for p in res)
    res = reuse!(res)
    search(X.descidx, q, res)

    for p in res
        C[p.id] = get(C, p.id, 0f0) + wdesc * p.weight
    end

    res = reuse!(res)
    search(X.readmeidx, q, res)
    for p in res
        C[p.id] = get(C, p.id, 0f0) + wreadme * p.weight
    end
    
    res = reuse!(res, k)
    for (id, weight) in C
        push_item!(res, id, weight)
    end

    R = Dict{String,Any}[]

    for p in res
        push!(R, package_data(X.D, p.id, p.weight))
    end

    R
end


serve()
