#=using Pkg
Pkg.add([
    PackageSpec(name="JSON"),
    PackageSpec(name="UnPack"),
])=#

using TOML, JSON, UnPack
using Downloads: download, RequestError

TOKEN = "token " * strip(read("PAT2.data", String))

function fetch_and_save_from_github_api(filename, url, update)
    if !update && isfile(filename)
        @info "$filename already exists"
        return
    end
    
    buff = download(url, IOBuffer(); verbose=false,
        headers=Dict(
            "User-Agent" => "donsadit@gmail.com",
            "Authorization" => TOKEN
        )
    )
    open(filename, "w") do f
        write(f, take!(buff))
    end
    # to be under gh limits 
    sleep(2)
end

function fetch_metadata(username, reponame, outpath, update)
    filename = joinpath(outpath, "Metadata.json")
    url = "https://api.github.com/repos/$(username)/$(reponame)"
    fetch_and_save_from_github_api(filename, url, update)
end

function fetch_readme(username, reponame, outpath, update)
    filename = joinpath(outpath, "Readme.json")
    url = "https://api.github.com/repos/$(username)/$(reponame)/readme"
    fetch_and_save_from_github_api(filename, url, update)
end

function fetch_repo(packagefile, outrepopath, update)
    D = TOML.parsefile(packagefile)
    repo = D["repo"]
    username, reponame = splitpath(repo)[end-1:end]
    # check github
    reponame = replace(reponame, ".jl.git" => ".jl")
    fetch_metadata(username, reponame, outrepopath, update)
    fetch_readme(username, reponame, outrepopath, update)
end

function main(;
        update = false,
        registrypath = "General",
        outpath = "PackageData"
    )
    
    mkpath(outpath)

    R = TOML.parsefile(joinpath(registrypath, "Registry.toml"))
    Packages = R["packages"]
    n = length(Packages)
    for (i, (uuid, p_)) in enumerate(Packages)
        @label retry_label
        @unpack name, path = p_
        # endswith(name, "_jll") && continue
        println("downloading $i of $n -- $name")
        packagefile = joinpath(registrypath, path, "Package.toml")
        outrepopath = joinpath(outpath, path)
        mkpath(outrepopath)
        try
            fetch_repo(packagefile, outrepopath, update)
        catch err
            @info "===== ERROR while fetching package $uuid, $p_"
            @info err
            if err isa RequestError
                if err.response.status == 403
                    #@info "Please launch the process in one hour or so"
                    #rethrow()  ## or sleep?
                    @info "RequestError: sleeping and retrying"
                    sleep(180)
                    @goto retry_label
                else
                    @info "Ignoring package - please check this issue"
                end
            else
                rethrow()
            end
        end
        
    end
end
