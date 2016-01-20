require 'httparty'
require 'optparse'
require 'set'

credentials_username = ARGV[0]
credentials_password = ARGV[1]
HOST_BASE_URL = "" #YOUR_BITBUCKET_SERVER_URL
REPO_NAME_FILTER_REGEX = /ios/i
EXTENSION_WHITELIST = ['.h', '.m', '.swift', '.plist']
FILE_VALIDATION_REGEX = /maliciousURLe.g./

raise 'Please configure your bitbucket server URL' if HOST_BASE_URL.empty?
raise 'Please specify your bitbucket credentials via ``ruby app.rb USERNAME PASSWORD``' if credentials_username.nil? || credentials_password.nil?

@host_url = "https://#{credentials_username}:#{credentials_password}@#{HOST_BASE_URL}"

def load_all_repos
	url = "#{@host_url}/rest/api/1.0/repos?limit=999"
	response = HTTParty.get(url)
	json = response.parsed_response
	repos = json['values']
	puts "did load #{repos.count} repos"
	repos
end

def filtered_repos_for_regex(all_repos, regex)
	ios_repos = all_repos.select { |repo| repo['name'] =~ regex}
	puts "did filter #{ios_repos.count} / #{all_repos.count} repos by regex #{regex.to_s}"
	ios_repos
end

def all_files_for_repo(repo)
	projectKey = repo['project']['key']
	repositorySlug = repo["slug"]
	url = "#{@host_url}/rest/api/1.0/projects/#{projectKey}/repos/#{repositorySlug}/files?limit=9999"
	response = HTTParty.get(url)
	json = response.parsed_response
	files = json['values']
	if files
		puts "did found #{files.count} files in repo #{repositorySlug}"
	else
		files = []
	end
	files
end

def all_types_for_files(files)
	types = Set.new
	files.each do |file|
		types << File.extname(file)
	end	
	types.to_a()
end

def filtered_files_by_extensions(files, whitelist_extension)
	filtered_files = files.select { |file| whitelist_extension.include?(File.extname(file)) }
	filtered_files_amount = files.count - filtered_files.count
	puts "Filtered out #{filtered_files_amount} files by extension whitelist #{whitelist_extension}"
	filtered_files
end

def content_of_file_and_repo(file, repo, start = 0)
	# /rest/api/1.0/projects/#{projectKey}/repos/#{repositorySlug}/browse/#{filePath}
	# ?start={start of last page} + {size of last page}
	projectKey = repo['project']['key']
	repositorySlug = repo["slug"]
	filePath = file
	url = "#{@host_url}/rest/api/1.0/projects/#{projectKey}/repos/#{repositorySlug}/browse/#{filePath}?start=#{start}"
	response = HTTParty.get(URI::encode(url))
	response.parsed_response
end

def check_file_of_repo(file, repo, hits, file_validation_regex)
	last_read_start = 0
	last_read_size = 0
	abort = false
	while (!abort) do
		file_content = content_of_file_and_repo(file,repo, last_read_start)
		lines_of_code = file_content['lines'].count
		is_last_page = file_content['isLastPage']
		last_read_size = file_content['size']

		for i in 0..lines_of_code-1 do
			text_line = file_content['lines'][i]['text']
			if text_line =~ file_validation_regex
				hits << "Line #{i} of file #{file}"
				abort = true
				break
			end
		end

		last_read_start += last_read_size
		abort = true if is_last_page
		print "." unless is_last_page
	end
end

def check_repo(repo, repo_hits, whitelist_extension, file_validation_regex)
	puts "Checking repo #{repo['slug']}"
	files = all_files_for_repo(repo)
	files = filtered_files_by_extensions(files, whitelist_extension)

	files.each do |file|
		puts "Checking file #{file}"
		file_hits = []
		check_file_of_repo(file, repo, file_hits, file_validation_regex)
		if file_hits.count > 0
			puts "Found #{file_hits.count} hits."
			repo_hits.concat file_hits
		end
	end
	puts "Repo #{repo['slug']} has the following hits:\n #{repo_hits}" unless repo_hits.empty?
end

repos = load_all_repos
ios_repos = filtered_repos_for_regex(repos, REPO_NAME_FILTER_REGEX)
hits_by_repo = {}
ios_repos.each do |repo|
	repo_hits = []
	check_repo(repo, repo_hits, EXTENSION_WHITELIST, FILE_VALIDATION_REGEX)
	hits_by_repo[repo['key']] = repo_hits
end
puts hits_by_repo