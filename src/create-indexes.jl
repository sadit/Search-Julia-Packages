using Glob, TextSearch, InvertedFiles, SimilaritySearch,
    JLD2, JSON, CategoricalArrays, Base64, DataFrames,
    Parquet2, Markdown

function one_package(metafile)
    M = JSON.parse(read(metafile, String))
    R = JSON.parse(read(joinpath(dirname(metafile), "Readme.json"), String))
    readme = String(base64decode(R["content"]))
    license = get(M, "license", nothing)
    license = license === nothing ? "" : get(license, "name", "")
    description = get(M, "description", nothing)
    description = description === nothing ? "" : description
    topics = get(M, "topics", nothing)
    topics = topics === nothing ? "" : join(topics, ' ')
    url = M["html_url"]
    name = replace(basename(url), r".jl$" => "")
    stargazers_count = get(M, "stargazers_count", 0)
    (; name, url, description, topics, readme, license, stargazers_count)
end

function package_dataset()
    D = DataFrame(
                  name = String[],
                  url = String[],
                  description = String[],
                  topics = String[],
                  readme = String[],
                  license = String[],
                  stargazers_count = Int32[]
                 )

    for metafile in glob("PackageData/*/*/Metadata.json")
        try
            data = one_package(metafile)
            push!(D, data)
        catch e
            @info "ERROR while loading data from $(dirname(metafile)), ignoring package"
            @info e 
        end
    end
    
    D
end

function search_packages(D, idx, query, k)
    res = KnnResult(k)
    search(idx, query, res)
    R = Dict{String,Any}[]

    for (i, p) in enumerate(res)
           r = D[p.id, :]
           desc = length(r.description) > 0 ? r.description : ""
           topics = length(r.topics) > 0 ? r.topics : ""
           push!(R, Dict(
               "name" => r.name,
               "description" => desc,
               "topics" => topics,
               "url" => r.url,
               "bm25-score" => round(abs(p.weight), digits=2),
               "gh-stars" => r.stargazers_count
              ))
    end

    R
end


function load_or_create_indexes(; datadir="data")
    mkpath(datadir)
    dataset_file = joinpath(datadir, "packages.parquet")
    nameindex_file = joinpath(datadir, "nameidx.jld2")
    descindex_file = joinpath(datadir, "descidx.jld2")
    readmeindex_file = joinpath(datadir, "readmeidx.jld2")

    if isfile(dataset_file)
        D = DataFrame(Parquet2.Dataset(dataset_file), copycols=false)
    else
        D = package_dataset()
        Parquet2.writefile(dataset_file, D)
    end
    
    if isfile(nameindex_file)
        nameidx, _ = loadindex(nameindex_file; staticgraph=true)
    else
        nameidx = BM25InvertedFile(TextConfig(qlist=[3]), D.name)
        append_items!(nameidx, D.name)
        saveindex(nameindex_file, nameidx)
    end
    
    if isfile(descindex_file)
        descidx, _ = loadindex(descindex_file; staticgraph=true)
    else
        descidx = BM25InvertedFile(TextConfig(nlist=[1], qlist=[4]), D.description) do t
            3 <= t.ndocs <= 1000
        end
        append_items!(descidx, D.description)
        saveindex(descindex_file, descidx)
    end
    
    if isfile(readmeindex_file)
        readmeidx, _ = loadindex(readmeindex_file; staticgraph=true)
    else
        readmeidx = BM25InvertedFile(TextConfig(nlist=[1]), D.readme) do t
            3 <= t.ndocs <= 1000
        end
        append_items!(readmeidx, D.readme)
        saveindex(readmeindex_file, readmeidx)
    end


    (; D, nameidx, descidx, readmeidx)
end

#=
P = load_or_create_indexes()
k = 5
search_packages(P.D, P.nameidx, "neural networks", k)
search_packages(P.D, P.descidx, "nearest neighbors similarity search", k)
=#