#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'

if ARGV.length < 1
	puts "Usage: #{$PROGRAM_NAME} [POD_NAME]"
	exit 1
end

uri = URI.parse("https://cocoadocs-api-cocoapods-org.herokuapp.com/pods/#{ARGV[0]}/stats")
quality = Net::HTTP.get_response(uri).body
if quality[0] != '{'
	puts quality
	exit 1
end
quality = JSON.parse(quality)['metrics']

uri = URI.parse("http://metrics.cocoapods.org/api/v1/pods/#{ARGV[0]}.json")
metrics = JSON.parse(Net::HTTP.get_response(uri).body)

quality.each do |metric|
	if (metric['modifier'] > 0 && !metric['applies_for_pod']) ||
	   (metric['modifier'] < 0 && metric['applies_for_pod'])
		puts "🚫 #{metric['title']}: #{metric['description']}"
	end
end

puts "\nCurrent quality estimate: #{metrics['cocoadocs']['quality_estimate']}"
