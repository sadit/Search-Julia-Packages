using TOML, JSON, DataFrames, CSV, Dates
using Downloads: download, RequestError

include("parse-registry.jl")

#=function fetch_readme_from_github(url, version; verbose=false)
    url = replace(url, "github.com" => "raw.githubusercontent.com")
    readmeurl = joinpath(url, "v" * version, "README.md") 
    verbose && (@show readmeurl)
    buff = download(readmeurl, IOBuffer(); verbose=false)  # keep this as false unless something fails with the http connection 
    String(take!(buff))
end=#

"""
    fetch_meta_from_github(repo, subdir, version; verbose=false)

Fetches meta information from github repo (description, topics, starts, readme)
"""
function fetch_meta_from_github(repo, subdir, version; verbose=false)
    url = string(repo, "/", subdir) 
    verbose && (@show url)
    buff = download(url, IOBuffer(); verbose=false)
    page = String(take!(buff))
    topics = String[]
    for m in eachmatch(r"/topics/([^\"]+)", page)
        push!(topics, m.captures[1])
    end

    stars = 0
    readme = ""

    description = match(r"""<meta name="description" content="(.+?)">""", page).captures[1]
    m = match(r"<span.*?>(\d+)</span>\s*?stars", page)
    m !== nothing && (stars = parse(Int, m.captures[1]))
    m = match(r"<article.*?>(.+)</article>"s, page)
    if m !== nothing
        readme = replace(m.captures[1], r"<.+?>" => "", "&nbsp;" => "\n", "&gt;" => ">", "&lt;" => "<")
    end

    description, join(topics, ';'), readme, stars
end

"""
    fetch_meta_from_gitlab(repo, subdir, version; verbose=false)


Retrieves metadata from gitlab repo; only fetches readme to be precise, the rest is set to blank strings.
See [@ref](`fetch_meta_from_github`)
"""
function fetch_meta_from_gitlab(repo, subdir, version; verbose=false)
    if occursin("github.com", repo)
        url = replace(repo, "github.com" => "raw.githubusercontent.com")
        if subdir != ""
            subdir = string(subdir, "/")
        end
        url = string(url, "/", version, "/", subdir, "README.md") 
    elseif occursin("gitlab.com", repo)
        url = string(repo, "/-/raw/", version, "/", "README.md") 
    else
        url = string(repo, "/", "README.md") 
    end

    verbose && (@info repo => url)
    buff = download(url, IOBuffer(); verbose=false)  # keep this as false unless something fails with the http connection 
    verbose && (@info repo => "OK")
    readme = String(take!(buff)) 
    stars = -1
    topics = ""
    description = ""
    description, topics, readme, stars
end

"""
    fetch_package_registry(row; verbose=false)

Fetches package from registry, uses row as a previous information source (a named tuple or a row of the packages dataframe)
"""
function fetch_package_registry(row; verbose=false)
    description = ""
    topics = ""
    readme = ""
    stars = -1
    statusmeta = 200

    if occursin("github.com", row.repo)
        try
            description, topics, readme, stars = fetch_meta_from_github(row.repo, row.subdir, row.version; verbose)
        catch err
            if err isa RequestError
                @info "ignoring metadata from $(row.name) / $(row.repo)"
                statusmeta = err.response.status
            else
                rethrow()
            end
        end
    else
        for version in ["master", string("v", row.version), "main"]
            try
                description, topics, readme, stars = fetch_meta_from_gitlab(row.repo, row.subdir, version; verbose)
                break
            catch err
                if err isa RequestError
                    @info "retry readme $(row.name) / $(row.repo) - $version"
                    statusmeta = err.response.status
                else
                    rethrow()
                end
            end
        end
    end


    (; row.name, row.uuid, row.repo, row.subdir, row.version, fetched=Dates.now(), statusmeta, description, topics, readme, stars)
end

"""
    update(registrypath, prevfile; verbose=false)


Updates a package database with new information retrived from a registry (e.g., a fresh pulled General registry)
"""
function update(registrypath, prevfile; verbose=false)
    updatedreg = parse_registry(registrypath)
    prev = load_meta_dataframe(prevfile)
    D = create_meta_dataframe()
    idxprev = Dict(name => i for (i, name) in enumerate(prev.name))
   
    n = length(updatedreg)
    count = 1
    for (name, reg) in updatedreg
        i = get(idxprev, name, 0)
        @info "precessing $count / $n - $name ($i)"
        count += 1
        if i == 0
            newreg = fetch_package_registry(reg; verbose)
            push!(D, newreg)
            continue
        end

        row = prev[i, :]
        if row.statusmeta in (200, 404)
            push!(D, row)
        else
            push!(D, fetch_package_registry(reg; verbose))
        end
    end

    D
end

"""
    load_meta_dataframe(filename)

Loads package registry's dataframe, some methods suppose some types that are specified in this function.
Some types are interpreted wrongly, also some methods expect empty strings instead of `missing` values.
"""
function load_meta_dataframe(filename)
    CSV.read(filename, DataFrame, missingstring="XXXXXXX", types=Dict(:fetched => DateTime, :statusmeta => Int, :stars => Int))
end


"""
    create_meta_dataframe()

Creates an empty package registry's dataframe
"""
function create_meta_dataframe()
    DataFrame(name=String[], uuid=String[], repo=String[], subdir=String[], version=String[], fetched=DateTime[], statusmeta=Int[], description=String[], topics=String[], readme=String[], stars=Int[])
end


"""
    create(registry; verbose = true)

Parses a fresh registry repo (e.g., General registry) and creates a package registry's dataframe
"""
function create(
        registry;
        verbose = true
    )
    
    D = create_meta_dataframe()
    Packages = parse_registry(registry)

    numpackages = length(Packages)
    for (i, (name, record)) in enumerate(Packages)
        @info "$i of $numpackages -- $(record.name) - $(record.repo) - $(Dates.now())"
        reg = fetch_package_registry(record; verbose)
        push!(D, reg)
        #rand() < 0.1 && break
    end

    D
end
