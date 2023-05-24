using Downloads: download
using SimilaritySearch, TextSearch, JSON, Markdown


function load_lunr_corpus_from_github(url; version="dev", branch="gh-pages")
    url = replace(url, "github.com" => "raw.githubusercontent.com")
    url = joinpath(url, "$branch/$version/search_index.js")
    @info url
    buff = download(url, IOBuffer())
    n = length("var documenterSearchIndex = ")
    s = String(take!(buff))
    [p for p in JSON.parse(@view s[n+1:end])["docs"] if !(p["category"] in ("section", "page"))]
end


function create_index(urlpkg; minfreq = 2, maxfreqp = 0.5)
    db = load_lunr_corpus_from_github(urlpkg)
    corpus = [p["text"] for p in db]
    docs = BM25InvertedFile(TextConfig(qlist=[4]), corpus) do t
        minfreq <= t.ndocs <= maxfreqp * length(corpus)
    end
    
    append_items!(docs, corpus)

    corpus = [split(p["title"], ".")[end] for p in db]
    names = BM25InvertedFile(TextConfig(qlist=[3]), corpus) do t
        minfreq <= t.ndocs <= maxfreqp * length(corpus)
    end
    
    append_items!(names, corpus)

    (; db, docs, names)
end

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

function search_doc(X, qtext; k=3, expansion=k, name_weight=1f0, doc_weight=0.5f0)
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
        println(rstrip(s["text"]))
        println()
    end
end

# X = create_index("https://github.com/sadit/SimilaritySearch.jl")
