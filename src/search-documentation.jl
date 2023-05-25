using Downloads: download
using SimilaritySearch, TextSearch, JSON, Markdown

"""
    get_doc(M::Module)

Retrieves documentations from a module, prepares a kind of database to be indexed
"""
function get_doc(M::Module)
    D = []
    for fn in names(M)
        f = getfield(M, fn)
        d = Base.Docs.doc(f)
        r = Dict{String,String}("title" => string(fn), "text" => Markdown.plain(d), "category" => string(typeof(f)))
        push!(D, r)
    end

    D
end

"""
    get_doc_lunr(url; version="dev", branch="gh-pages")

Retrieves documentations from a github repo that contains a Lunr search index. This is useful to search without installing a package.

It receives the url to avoid loading the package dataframe. It also supposes using `gh-pages` and more things.
"""
function get_doc_lunr(url; version="dev", branch="gh-pages")
    url = replace(url, "github.com" => "raw.githubusercontent.com")
    url = joinpath(url, "$branch/$version/search_index.js")
    @info url
    buff = download(url, IOBuffer())
    n = length("var documenterSearchIndex = ")
    s = String(take!(buff))
    [p for p in JSON.parse(@view s[n+1:end])["docs"] if !(p["category"] in ("section", "page"))]
end

"""
    create_index(db; minfreq=2, maxfreqp=0.5, nlist=Int[], qlist=Int[4])

Creates and index from a given dataset. See [@ref](`get_doc`) and [@ref](`get_doc_lunr`)
"""
function create_index(db; minfreq=2, maxfreqp=0.5, nlist=Int[], qlist=Int[4])
    corpus = [p["text"] for p in db]
    docs = BM25InvertedFile(TextConfig(qlist=[4]), corpus) do t
        minfreq <= t.ndocs <= maxfreqp * length(corpus)
    end
    
    append_items!(docs, corpus)

    corpus = [split(p["title"], ".")[end] for p in db]
    names = BM25InvertedFile(TextConfig(;qlist), corpus) do t
        minfreq <= t.ndocs <= maxfreqp * length(corpus)
    end
    
    append_items!(names, corpus)
    (; db, docs, names)
end

"""
    search_doc_api(X, qtext; k=3)

Searches (an index and database tuple `create_index`) and returns a list of dictionaries (useful for JSON serialization)
"""
function search_doc_api(X, qtext; k=3)
    res = KnnResult(k)
    search(X.invfile, qtext, res)

    R = Dict[]
    for p in res
        r = Dict{String,Any}()
        push!(R, r)
        s = X.db[p.id]
        r["title"] = s["title"]
        r["category"] = s["title"]
        r["score"] = abs(p.weight)
        r["text"] = s["text"]
    end

    R
end

"""
    search_doc(X, qtext; k=3, expansion=k, name_weight=1f0, doc_weight=0.5f0, snippet=128)

Searches and index (an index and a database tuple created with [@ref](`create_index`)), showing results on the screen

- `X`: the index and db
- `qtext`: the query in plain text
- `k`: the number of expected results
- `expansion`: this method uses two indexes (package names and docs) and reranking, this factor indicates an expansion factor to compute individual ranks
- `name_weight`: The weight given to the _name_ score
- `doc_weight`: The weight given to the _documentation_ score
- `snippet`: Controls the size of the snippet to show, snippet=0 suppress it, snippet < 0 shows the entire snippet, snippet > 0 shows that number of chars (can raise some errors on unicode chars!!) 
"""
function search_doc(X, qtext; k=3, expansion=k, name_weight=1f0, doc_weight=0.5f0, snippet=128)
    res = KnnResult(expansion * k)
    search(X.names, qtext, res)
    D = Dict(p.id => name_weight * p.weight for p in res)
    res = reuse!(res)
    search(X.docs, qtext, res)
    for p in res
        D[p.id] = get(D, p.id, 0f0) + doc_weight * p.weight
    end

    res = reuse!(res, k)
    for (id, w) in D
        push_item!(res, id, w)
    end

    for p in res
        s = X.db[p.id]
        score = round(abs(p.weight); digits=2)
        display(md"""## $(s["title"]) -- category: $(s["category"]) -- score: $score""")
        txt = s["text"]
        if snippet > 0    
            display(Markdown.parse(txt[1:min(snippet, length(txt))]))  # WARNING this can broke unicode composite chars
        elseif snippet < 0
            display(Markdown.parse(txt))
        # else 0 => don't show
        end
        println("\n\n")
    end
end

