using Dates
using MarketStore: download_spy_minutes

default_csv_path() = "spy_1min_polygon.csv"
default_start_date() = Date(1990, 1, 1)
default_finish_date() = today()

select_path(args) = isempty(args) ? default_csv_path() : args[1]
select_start(args) = length(args) ≥ 2 ? Date(args[2]) : default_start_date()
select_finish(args) = length(args) ≥ 3 ? Date(args[3]) : default_finish_date()

csv_path = select_path(ARGS)
range_start = select_start(ARGS)
range_finish = select_finish(ARGS)

@info "Downloading SPY minute aggregates" path=csv_path start=range_start finish=range_finish

download_spy_minutes(csv_path; start=range_start, finish=range_finish)
