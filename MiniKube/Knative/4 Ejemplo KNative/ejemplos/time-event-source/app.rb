require 'optparse'
require 'net/http'
require 'uri'

# Default CLI options if omitted
options = {
    :sink => "http://localhost:8080",
    :interval => 1
}

# Parse CLI flags
opt_parser = OptionParser.new do |opt|
    opt.on("-s", "--sink SINK", "Location to send events") do |sink|
        options[:sink] = sink
    end

    opt.on("-i", "--interval INTERVAL", "Poll frequency") do |interval|
        options[:interval] = interval.to_i
    end
end
opt_parser.parse!

# Send the current time on the given interval
# to the given sink
uri = URI.parse(options[:sink])
header = {'Content-Type': 'text/plain'}
loop do
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = Time.now.to_s
    response = http.request(request)
    sleep options[:interval]
end