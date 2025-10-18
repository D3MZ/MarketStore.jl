module MarketStore

using Dates
using HTTP
using JSON3

const polygon_host = "https://api.polygon.io"
const epoch = DateTime(1970, 1, 1)
const polygon_spacing = Millisecond(12_000)
const polygon_spacing_seconds = Dates.value(polygon_spacing) / 1000
const polygon_last_request = Ref{Union{Nothing, DateTime}}(nothing)

format_endpoint(day::Date) = Dates.format(day, dateformat"yyyy-mm-dd")
format_endpoint(moment::DateTime) = Dates.format(moment, dateformat"yyyy-mm-ddTHH:MM:SS")
format_endpoint(value) = string(value)

function obtain_polygon_key()
    key = get(ENV, "POLYGON", nothing)
    isnothing(key) && error("Missing Polygon API key in ENV[\"POLYGON\"]")
    return key
end

function append_api_key(url, key)
    occursin("apiKey=", url) && return url
    separator = occursin('?', url) ? "&" : "?"
    return string(url, separator, "apiKey=", key)
end

function throttle_polygon_requests()
    last_request = polygon_last_request[]
    isnothing(last_request) && return
    elapsed = now() - last_request
    wait = polygon_spacing - elapsed
    wait > Millisecond(0) && sleep(Dates.value(wait) / 1000)
end

function compose_polygon_url(ticker; start=Date(1990, 1, 1), finish=today(), multiplier=1, timespan="minute", adjusted=true, limit=50_000, sort="asc", key=obtain_polygon_key())
    base = string(
        polygon_host,
        "/v2/aggs/ticker/",
        ticker,
        "/range/",
        multiplier,
        "/",
        timespan,
        "/",
        format_endpoint(start),
        "/",
        format_endpoint(finish),
    )
    query = string(
        "adjusted=",
        adjusted ? "true" : "false",
        "&limit=",
        limit,
        "&sort=",
        sort,
        "&apiKey=",
        key,
    )
    return string(base, "?", query)
end

function request_polygon(url; attempts=5, pause=1.0)
    attempt = 1
    while attempt ≤ attempts
        throttle_polygon_requests()
        polygon_last_request[] = now()
        @info "Requesting Polygon aggregates" attempt=attempt url=url
        response = HTTP.get(url)
        status = response.status
        status == 200 && return response
        status == 429 && @info "Polygon rate limit encountered"
        status ≥ 500 && @info "Polygon server error" status=status
        status == 429 || status ≥ 500 || error("Polygon request failed with HTTP status $(status)")
        wait_seconds = max(pause, polygon_spacing_seconds)
        sleep(wait_seconds)
        attempt += 1
        pause = max(pause * 2, wait_seconds)
    end
    error("Polygon request exceeded retry attempts")
end

function normalize_bar(entry)
    millis = Int(get(entry, :t, 0))
    timestamp = epoch + Millisecond(millis)
    open = get(entry, :o, 0.0)
    high = get(entry, :h, 0.0)
    low = get(entry, :l, 0.0)
    close = get(entry, :c, 0.0)
    volume = get(entry, :v, 0.0)
    transactions = get(entry, :n, 0)
    vwap = get(entry, :vw, nothing)
    return (
        timestamp=timestamp,
        open=open,
        high=high,
        low=low,
        close=close,
        volume=volume,
        transactions=transactions,
        vwap=vwap,
    )
end

function write_bar(io, bar)
    timestamp = Dates.format(bar.timestamp, dateformat"yyyy-mm-ddTHH:MM:SS.sss")
    vwap = isnothing(bar.vwap) ? "" : string(bar.vwap)
    line = string(
        timestamp,
        ",",
        bar.open,
        ",",
        bar.high,
        ",",
        bar.low,
        ",",
        bar.close,
        ",",
        bar.volume,
        ",",
        bar.transactions,
        ",",
        vwap,
        '\n',
    )
    write(io, line)
end

function stream_polygon_minutes(ticker, csv_path; start=Date(1990, 1, 1), finish=today(), multiplier=1, timespan="minute", adjusted=true, limit=50_000, sort="asc")
    key = obtain_polygon_key()
    url = compose_polygon_url(ticker; start=start, finish=finish, multiplier=multiplier, timespan=timespan, adjusted=adjusted, limit=limit, sort=sort, key=key)
    open(csv_path, "w") do io
        write(io, "timestamp,open,high,low,close,volume,transactions,vwap\n")
        while true
            response = request_polygon(url)
            payload = JSON3.read(response.body)
            status = hasproperty(payload, :status) ? String(payload.status) : ""
            status ∈ ("OK", "DELAYED") || error("Polygon response status $(status)")
            results = hasproperty(payload, :results) ? payload.results : Any[]
            isempty(results) && @info "Polygon page returned no bars" url=url
            for index in eachindex(results)
                bar = normalize_bar(results[index])
                write_bar(io, bar)
            end
            next_url = hasproperty(payload, :next_url) ? payload.next_url : nothing
            isnothing(next_url) && break
            url = append_api_key(String(next_url), key)
        end
    end
    @info "Finished writing Polygon bars" path=csv_path
end

download_spy_minutes(csv_path; kwargs...) = stream_polygon_minutes("SPY", csv_path; kwargs...)

end
