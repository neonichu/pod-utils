#!/usr/bin/env ruby

#
# Scripts which checks if a list of Pods has any test targets.
# The list is read from ~/Desktop/pods.txt
#

require 'base64'
require 'cocoapods'
require 'json'
require 'net/http'
require 'pathname'
require 'tmpdir'
require 'xcodeproj'

class GitHub
	attr_reader :owner
	attr_reader :repo_name

	def fetch_file(path)
		Base64.decode64(fetch_json("contents/#{URI.encode(path)}")['content'])
	end

	def files
		recursive_tree(latest_commit)
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

	def latest_commit
		result = fetch_json('commits')
		result.first['sha'] if result.class == [].class
	end

	def recursive_tree(sha)
		return [] if sha.nil?
		result = fetch_json("git/trees/#{sha}?recursive=1")
		result['tree'].map { |a| a['path'] }
	end
end

def find_tests(project)
	project.targets.select do |target|
		product_type = nil

		begin
			product_type = target.product_type.to_s
		rescue
			next
		end

		product_type.end_with?('bundle.unit-test')
	end
end

def has_tests(project_file_content)
	test_targets = nil

	Dir.mktmpdir do |dir|
		path = "#{dir}/foo.xcodeproj"
		FileUtils.mkdir_p(path)
		File.write(Pathname.new(path) + 'project.pbxproj', 
			project_file_content)

		test_targets = find_tests(Xcodeproj::Project.open(path))
	end

	test_targets.count > 0
end

def pod_has_tests(pod_name)
	spec = spec_with_name(pod_name)
	if spec.source[:git].nil?
		puts "#{pod_name} has no Git source."
		return false
	end

	owner = spec.source[:git].split('/')[-2]
	repo_name = spec.source[:git].split('/')[-1].split('.').first

	gh = GitHub.new(owner, repo_name)
	gh.files.select { |f| f.end_with?('pbxproj') }.each do |xcproj|
		return if has_tests(gh.fetch_file(xcproj))
	end

	puts "#{gh.repo_name} has no tests."
end

def spec_with_name(pod_name)
	set = Pod::SourcesManager.search(Pod::Dependency.new(pod_name))
	set.specification.root unless set.nil?
end

##########################################################################

File.open("#{ENV["HOME"]}/Desktop/pods.txt").each do |pod_name|
	pod_has_tests(pod_name.strip)
end
