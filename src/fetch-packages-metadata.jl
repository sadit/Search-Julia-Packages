using TOML, JSON, DataFrames, CSV, Dates
using Downloads: download, RequestError

include("parse-registry.jl")

function fetch_readme_from_github(url, version; verbose=false)
    url = replace(url, "github.com" => "raw.githubusercontent.com")
    readmeurl = joinpath(url, "v" * version, "README.md") 
    verbose && (@show readmeurl)
    buff = download(readmeurl, IOBuffer(); verbose=false)  # keep this as false unless something fails with the http connection 
    String(take!(buff))
end

function fetch_meta_from_github(url; verbose=false)
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
    m = match(r"<span.*?>(\d+)</span>\s*?stars", d)
    m !== nothing && (stars = parse(Int, m.captures[1]))
    m = match(r"<article.*?>(.+)</article>"s, d)
    if m !== nothing
        readme = replace(m.captures[1], r"<.+?>" => "", "&nbsp;" => "\n", "&gt;" => ">", "&lt;" => "<")
    end

    description, join(topics, ';'), readme, stars
end

function fetch_readme(repo, subdir, version; verbose=false)
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
    String(take!(buff))
end

function fetch_package_registry(row; verbose=false)
    if ismissing(row.subdir) || isempty(row.subdir)
        url = row.repo
        subdir = ""
    else
        url =  joinpath(row.repo, row.subdir) 
        subdir = row.subdir
    end

    description = ""
    topics = ""
    readme = ""
    statusmeta = 200
    statusreadme = 200

    if occursin("github.com", row.repo)
        try
            description, topics = fetch_meta_from_github(url; verbose)
        catch err
            if err isa RequestError
                @info "ignoring metadata from $(row.name) / $(row.repo)"
                statusmeta = err.response.status
            else
                rethrow()
            end
        end
    end

    for version in ["master", string("v", row.version), "main"]
        try
            readme = fetch_readme(row.repo, subdir, version; verbose)
            break
        catch err
            if err isa RequestError
                @info "retry readme $(row.name) / $(row.repo) - $version"
                statusreadme = err.response.status
            else
                rethrow()
            end
        end
    end

    (; row.name, row.uuid, row.repo, subdir, row.version, fetched=Dates.now(), statusmeta, statusreadme, description, topics, readme)
end


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
        if row.readme == ""
            push!(D, fetch_package_registry(reg; verbose))
        else
            push!(D, row)
        end
    end

    D
end

function load_meta_dataframe(filename)
    CSV.read(filename, DataFrame, missingstring="XXXXXXX", types=Dict(:fetched => DateTime, :statusmeta => Int, :statusreadme => Int))
end

function create_meta_dataframe()
    DataFrame(name=String[], uuid=String[], repo=String[], subdir=String[], version=String[], fetched=DateTime[], statusmeta=Int[], statusreadme=Int[], description=String[], topics=String[], readme=String[])
end

function create(
        registry;
        update = false,
        verbose = true
    )
    
    D = create_meta_dataframe()
    Packages = parse_registry(registry)

    numpackages = length(Packages)
    for (i, (name, row)) in enumerate(Packages)
        occursin("github", row.repo) && continue
        @info "$i of $numpackages -- $(row.name) - $(row.repo) - $(Dates.now())"
        reg = fetch_package_registry(row; verbose)
        push!(D, reg)
        #rand() < 0.1 && break
    end

    D
end
