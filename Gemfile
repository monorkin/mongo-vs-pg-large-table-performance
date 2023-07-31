source "https://rubygems.org"
ruby ">= 3.2.0"

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem "activerecord"
gem "activerecord-copy"
gem "activesupport"
gem "zeitwerk"
gem "parallel"

gem "pg"
gem "mysql2"
gem "mongoid", "~> 7.0.5"
