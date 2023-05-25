using Oxygen, HTTP, SimilaritySearch, SimSearchManifoldLearning

include("src/packages.jl")

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
    wname = get(params, "wname", 1f0)
    wreadme = get(params, "wreadme", 0.3333f0)

    search_pkgs(X, q; k, wname, wreadme)
end


serve()
