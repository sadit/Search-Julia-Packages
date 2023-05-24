using TOML, JSON, DataFrames, CSV, Glob

function parse_registry(registrypath = "General") 
    R = TOML.parsefile(joinpath(registrypath, "Registry.toml"))
    Packages = R["packages"]
    n = length(Packages)
    D = Dict{String,NamedTuple}()
    for (uuid, p) in Packages
        name, path = p["name"], p["path"]
        packagefile = joinpath(registrypath, path, "Package.toml")
        pkg = TOML.parsefile(packagefile)
        repo = replace(pkg["repo"], r".git$" => "")
        subdir = get(pkg, "subdir", "")
        verfile = joinpath(registrypath, path, "Versions.toml")
        V = TOML.parsefile(verfile)
        version = VersionNumber.(keys(V)) |> maximum |> string
        D[name] = (; name, uuid, repo, subdir, version)
        #D[name] = uuid
    end

    D
end

function parse_registry_table(registrypath = "General") 
    Packages = parse_registry(registrypath)
    D = DataFrame(name=String[], uuid=String[], repo=String[], subdir=String[], version=String[])
    for (name, p) in Packages
        push!(D, p)
    end

    D
end

function create_registry_table(regname = "General")
    outname = "$(basename(regname))-packages.csv"
    @info "loading $regname"
    D = parse_registry_table(regname)
    @info "saving $outname"
    CSV.write(outname, D)
end
