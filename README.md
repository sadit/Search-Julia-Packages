# Search Julia packages and documentation

This repository contains fulltext indexes for searching for packages and documentation.

It also contains a UMAP 2d visualization, and a small DBSCAN clustering exercise. In the road, a number of resources were generated (knn-graph, 2d and 3d UMAP projections, indexes, a parquet database containing package's information).

Particularly, the database contains information that may not follow an OSS license. This dataset was made only for research purposes.

# Running scripts


## Usage

- Clone the repository
- Instantiate the repository
- Include `src/search-documentation.jl` or `src/packages.jl`
- Create or fetch a database, index and search
- Create an indexes In a julia REPL, inclde `src/create-indexes.jl`, run `load_or_create_indexes()`


## Examples
- Search for packages: <https://github.com/sadit/Search-Julia-Packages/blob/main/search-pkgs.ipynb>
- Search documentation: <https://github.com/sadit/Search-Julia-Packages/blob/main/search-docs.ipynb>
- Clustering packages by name and descriptions: <https://github.com/sadit/Search-Julia-Packages/blob/main/clustering.ipynb>

## Goal

Help reducing gap for people looking for packages or looking for some clustered entry to packages (e.g., see candidate packages that solve some problem).

## Creating the database
- Please check the notebooks
- For packages: please check `src/parse-registry.jl` and `src/packages.jl`.
  - The first time you will need to clone a registry, and run `create`, and save the dataframe.
  - After that, you should update dataframes with `update` function.

- For documentation: please check `src/search-documentation.jl`


## Ideas

- Create a tool to search packages from commandline, it can be stand alone or running on a centralized server with options to search on names, descriptions, and readme.
- Use another database backend, e.g., LevelDB or some SQL based db.
- Add scores for popularity (e.g., stars, graph-centrality).
- Use LLM embeddings can be interesting but running them can be costly.
- Index and search function names and function documentations.
- Help developers to find packages or functions.
  