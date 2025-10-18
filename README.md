# MarketStore

[![Build Status](https://github.com/D3MZ/MarketStore.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/D3MZ/MarketStore.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/D3MZ/MarketStore.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/D3MZ/MarketStore.jl)

Downloads polygon data into CSV.
Mostly Vibe coded AI SLOP.

Ensure you have your POLYGON exported
```bash
    echo 'export POLYGON="your_api_key_here"' >> ~/.bash_profile
```

Then you can read it directly in julia
```julia
julia> ENV["POLYGON"]
"abc123"
```