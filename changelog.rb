#!/usr/bin/env ruby

#
# Script for generating a ChangeLog file from GitHub releases
# Follows http://keepachangelog.com for formatting
#

require 'base64'
require 'cocoapods'
require 'json'
require 'net/http'
require 'pathname'

class GitHub
	attr_reader :owner
	attr_reader :repo_name

	def releases
		fetch_json('releases?per_page=100')
	end

	def initialize(owner, repo_name)
		@owner = owner
		@repo_name = repo_name
	end

	private

	def base_path
		"https://api.github.com/repos/#{@owner}/#{@repo_name}/"
	end

	def fetch_json(path)
		headers = {}
		if ENV['GITHUB_API_TOKEN']
			headers['Authorization'] = "token #{ENV['GITHUB_API_TOKEN']}"
		end

		desired_uri = URI(base_path + path)
		http = Net::HTTP.new(desired_uri.host, desired_uri.port)
		http.use_ssl = desired_uri.scheme == 'https'
		JSON.parse(http.get2("#{desired_uri.path}?#{desired_uri.query}",
			headers).body)
	end
end


##########################################################################

repo = GitHub.new('contentful', 'contentful.objc')
puts <<-HEADER
# Change Log
All notable changes to this project will be documented in this file.

HEADER

repo.releases.each do |release|
puts <<-RELEASE
## [#{release['tag_name']}] - #{release['created_at'].split('T')[0]}

#{release['body']}

RELEASE
end
