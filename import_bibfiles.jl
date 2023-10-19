
data_folder = ARGS[end]
@assert ispath(data_folder)

publication_folder = joinpath(@__DIR__, "content/publication/")
@assert ispath(publication_folder)

@info "research data folder: $data_folder"

folders = [
    ("journal", "journals", 2),
    ("conference", "conferences", 1),
    ("preprint", "submitted", 3),
]

for (folder, bibfile, pubtype) in folders
    @info "Folder: $folder"
    pubfolder = joinpath(publication_folder, folder)
    if ispath(pubfolder)
        rm(pubfolder, recursive=true)
    end
    @info `academic import --compact --bibtex $(joinpath(data_folder, bibfile * ".bib")) --publication-dir $pubfolder`
    run(`academic import --compact --bibtex $(joinpath(data_folder, bibfile * ".bib")) --publication-dir $pubfolder`)
    for subdir in readdir(pubfolder, join=true)
        @info "$subdir"
        if !isdir(subdir)
            @info "skipping $subdir"
            continue
        end
        file = joinpath(subdir, "index.md")
        raw_content = open(file) do f
            read(f, String)
        end
        res_string = replace(raw_content, r"publication_types:\n- '[0-9]'" => "publication_types:\n- '$pubtype'")
        open(file, "w") do f
            write(f, res_string)
        end
    end
end

# rm -rf content/publication/journal/*
# academic import --bibtex $1/publications/journals.bib --publication-dir content/publication/journal/

# rm -rf content/publication/conference/*
# academic import --bibtex $1/publications/conferences.bib --publication-dir content/publication/conference/

# rm -rf content/publication/preprint/*
# academic import --bibtex $1/publications/submitted.bib --publication-dir content/publication/preprint/
# sed -E -z "s/publication_types:\n- '0'/publication_types:\n- '1'/"
