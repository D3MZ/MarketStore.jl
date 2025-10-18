using Dates
using MarketStore: download_minutes

default_input_path() = "sp500.csv"
default_output_dir() = "sp500"
default_start_date() = Date(1990, 1, 1)
default_finish_date() = today()
timestamp_format() = dateformat"yyyy-mm-ddTHH:MM:SS.sss"

select_input(args) = isempty(args) ? default_input_path() : args[1]
select_output_dir(args) = length(args) ≥ 2 ? args[2] : default_output_dir()
select_start(args) = length(args) ≥ 3 ? Date(args[3]) : default_start_date()
select_finish(args) = length(args) ≥ 4 ? Date(args[4]) : default_finish_date()
select_limit(args) = length(args) ≥ 5 ? parse(Int, args[5]) : nothing

to_datetime(value::Date) = DateTime(value)
to_datetime(value::DateTime) = value

function finish_datetime(value::Date)
    return DateTime(value) + Day(1) - Minute(1)
end

finish_datetime(value::DateTime) = value

function read_last_timestamp(path)
    open(path, "r") do io
        last_line = nothing
        for line in eachline(io)
            stripped = strip(line)
            isempty(stripped) && continue
            startswith(stripped, "timestamp,") && continue
            last_line = stripped
        end
        isnothing(last_line) && return nothing
        parts = split(last_line, ','; limit=2)
        isempty(parts[1]) && return nothing
        return DateTime(parts[1], timestamp_format())
    end
end

function read_tickers(path)
    open(path, "r") do io
        iterator = Iterators.drop(eachline(io), 1)
        symbols = String[]
        for line in iterator
            candidate = strip(split(line, ','; limit=2)[1])
            isempty(candidate) && continue
            push!(symbols, candidate)
        end
        return symbols
    end
end

input_path = select_input(ARGS)
output_dir = select_output_dir(ARGS)
range_start = select_start(ARGS)
range_finish = select_finish(ARGS)
ticker_limit = select_limit(ARGS)

mkpath(output_dir)

tickers = read_tickers(input_path)
count = isnothing(ticker_limit) ? length(tickers) : min(length(tickers), ticker_limit)
range_start_dt = to_datetime(range_start)
range_finish_dt = finish_datetime(range_finish)

@info "Downloading minute aggregates for S&P 500 tickers" input=input_path output=output_dir start=range_start finish=range_finish total=count

for (index, ticker) in enumerate(tickers)
    !isnothing(ticker_limit) && index > ticker_limit && break
    csv_path = joinpath(output_dir, "$(ticker)_1min_polygon.csv")
    resume = false
    start_point = range_start_dt
    if isfile(csv_path)
        last_timestamp = read_last_timestamp(csv_path)
        if isnothing(last_timestamp)
            resume = false
            start_point = range_start_dt
        else
            resume = true
            start_point = max(range_start_dt, last_timestamp + Minute(1))
            if start_point > range_finish_dt
                @info "Ticker already up to date" ticker=ticker path=csv_path
                continue
            end
        end
    end
    if start_point > range_finish_dt
        @info "Ticker already out of requested range" ticker=ticker path=csv_path
        continue
    end
    @info "Downloading ticker minutes" ticker=ticker index=index total=count path=csv_path start=start_point resume=resume
    download_minutes(ticker, csv_path; start=start_point, finish=range_finish, resume=resume)
end
