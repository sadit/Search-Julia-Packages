# Search Julia Packages

This repository contains fulltext indexes, a UMAP 2d visualization, and a small DBSCAN clustering exercise. In the road, a number of resources were generated (knn-graph, 2d and 3d UMAP projections, indexes, a parquet database containing package's information).

Particularly, the database contains information that may not follow an OS license. This dataset was made only for research purposes.

# Running scripts


## Creating indexes

- Instantiate the repository
- Create the database
- In a julia REPL, inclde `src/create-indexes.jl`, run `load_or_create_indexes()`

A database is bundled and indexes are created and saved. If database and indexes are already created this function will load them. You can solve searches as follow

```julia

P = load_or_create_indexes()
k = 5
search_packages(P.D, P.nameidx, "neural networks", k)
search_packages(P.D, P.descidx, "nearest neighbors similarity search", k)
search_packages(P.D, P.readmeidx, "nearest neighbors similarity search", k)
```

## Notebooks

There are two notebooks

- `clustering.ipynb` creates a UMAP visualization and a DBSCAN cluster is also generated. It saves these data into files.
- `search.ipynb` a small search example.

## Files
```
120K clusters.jld2 <- cluster computed with DBSCAN
5.2M descidx.jld2 <- pkg's description index
2.2M nameidx.jld2 <- pkg's name index
1.1M package-all-knns-10.jld2 <- all knn graph for packages
 14M packages.parquet <- packages database
 11M readmeidx.jld2 <- pkg's readme index
176K umap-embeddings.jld2 <- 2d and 3d umap projections
```

## Fulltext indexes for Julia packages using BM25. In particular, there are 3 indexes:
  - Package names index `data/nameidx.jld2`
  - Package descriptions index `data/descidx.jld2`
  - Package readmes index `data/readmeidx.jld2`
  

## Creating the database

- Clone the General registry on the main directory
- Get a token from github to use the API, store it in a file named `PAT2.data`
- In a julia REPL, instantiate the repository, include `src/fetch-packages-metadata.jl` and execute `main()`. It will last some hours to prevent github block the token.
