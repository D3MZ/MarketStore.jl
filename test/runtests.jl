using MarketStore
using Test
using Dates

@testset "MarketStore.jl" begin
    @test fetch_earliest("SPY") isa DateTime
end
