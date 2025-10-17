module MarketStore

using Dates

export fetch_earliest

function fetch_earliest(instrument)
    sql = "SELECT min(start_time) FROM candles WHERE instrument = '$instrument'"
    output = read(`clickhouse-client -q $sql`, String)
    DateTime(strip(output), dateformat"yyyy-mm-dd HH:MM:SS")
end

end
