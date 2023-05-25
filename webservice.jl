using Oxygen, HTTP, SimilaritySearch, SimSearchManifoldLearning

include("src/run-fetch.jl")
include("src/create-indexes.jl")

pkgs = load_meta_dataframe("General-packages-1.csv.gz")
X = load_or_create_indexes(pkgs)

@post "/search/name" function (req)
    params = Oxygen.json(req)
    k = params["k"]
    q = params["q"]
    search_packages(X.pkgs, X.nameidx, q, k)
end

@post "/search" function (req)
    params = Oxygen.json(req)
    k = params["k"]
    q = params["q"]

    Rdesc = KnnResult(10k)
    Rreadme = KnnResult(10k)
    wname = get(params, "name_weight", 1f0)
    wreadme = get(params, "readme_weight", 0.33333f0)

    res = KnnResult(10k)
    search(X.nameidx, q, res)
    C = Dict{UInt32,Float32}(p.id => wname * p.weight for p in res)

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
        push!(R, package_data(X.pkgs, p.id, p.weight))
    end

    R
end


serve()
