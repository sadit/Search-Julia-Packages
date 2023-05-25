using Glob, TextSearch, InvertedFiles, SimilaritySearch,
    JLD2, JSON, CategoricalArrays, Base64, DataFrames,
    Parquet2, Markdown

function package_data(D, id, weight)
    r = D[id, :]

    subdir = length(r.subdir) > 0 ? string("/", subdir) : ""
    url = string(r.repo, subdir)
    Dict(
        "id" => id,
        "name" => r.name,
        "url" => url,
        "description" => r.description,
        "topics" => r.topics,
        "score" => round(abs(weight), digits=2),
        "stars" => r.stars
    )
end

function search_packages(D, idx, query, k)
    res = KnnResult(k)
    search(idx, query, res)
    R = Dict{String,Any}[]

    for (i, p) in enumerate(res)
        push!(R, package_data(D, p.id, p.weight))
    end

    R
end

function load_or_create_indexes(pkgs; datadir="data")
    mkpath(datadir)
    nameindex_file = joinpath(datadir, "nameidx.jld2")
    readmeindex_file = joinpath(datadir, "readmeidx.jld2")

    if isfile(nameindex_file)
        nameidx, _ = loadindex(nameindex_file; staticgraph=true)
    else
        nameidx = BM25InvertedFile(TextConfig(qlist=[3]), pkgs.name)
        append_items!(nameidx, pkgs.name)
        saveindex(nameindex_file, nameidx)
    end

    if isfile(readmeindex_file)
        readmeidx, _ = loadindex(readmeindex_file; staticgraph=true)
    else
        corpus = [string(a, " ", b, " ", c) for (a, b, c) in zip(pkgs.description, pkgs.topics, pkgs.readme)]
        readmeidx = BM25InvertedFile(TextConfig(nlist=[1], qlist=[4]), corpus) do t
            3 <= t.ndocs <= 1000
        end
        append_items!(readmeidx, corpus)
        saveindex(readmeindex_file, readmeidx)
    end
    readmeindex_file = joinpath(datadir, "readmeidx.jld2")

    (; pkgs, nameidx, readmeidx)
end

#=
P = load_or_create_indexes()
k = 5
search_packages(P.D, P.nameidx, "neural networks", k)
search_packages(P.D, P.readmeidx, "nearest neighbors similarity search", k)
=#
