using Glob, TextSearch, InvertedFiles, SimilaritySearch,
    JLD2, JSON, CategoricalArrays, Base64, DataFrames, Markdown


"""
    package_data(D, id, weight)

Creates a dictionary with package information, useful to present or JSON serialization (e.g., web api)
"""
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

"""
    search_packages(D, idx, query, k)


Find best `k` matches for the given `query` in the given index `idx`. 
Return an array of results with [@ref](package_data).

"""
function search_packages(D, idx, query, k)
    res = KnnResult(k)
    search(idx, query, res)
    R = Dict{String,Any}[]

    for (i, p) in enumerate(res)
        push!(R, package_data(D, p.id, p.weight))
    end

    R
end

"""
    load_or_create_indexes(pkgs; datadir="data")

Load the set name and readme (description, topics, readme, etc) indexes,
using the `pkgs` dataframe, see [@ref](`load_meta_dataframe`).

Creates indexes and save them if they are not found in the given path.
"""
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

