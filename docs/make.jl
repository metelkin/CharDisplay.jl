push!(LOAD_PATH,"Y:/_raspberry/")

using Documenter, CharDisplay

makedocs(
    sitename = "CharDisplay Documentation",
    modules = [CharDisplay],
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/metelkin/CharDisplay.jl.git",
    target = "build",
)
