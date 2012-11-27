#require 'rspec/core/rake_task'
require 'yard'
require 'yard/rake/yardoc_task'
require 'rake/clean'

lib = File.expand_path('../lib/', __FILE__)

$:.unshift lib unless $:.include?(lib)

CLEAN.include('gless*.gem')
CLOBBER.include('doc/', '.yardoc')

desc "Build the gless gem."
task :build do
  sh %{gem build gless.gemspec}
end

desc "Build then install the gless gem."
task :install => :build do
  require 'gless/version'
  sh %{gem install gless-#{Gless::VERSION}.gem}
end

#desc "Run specs for gless gem"
#RSpec::Core::RakeTask.new do
#end

desc "Generate yard documentation for the api"
YARD::Rake::YardocTask.new do
end

desc "Clean existing gems and re-install"
task :devinst do
  ['clean','build','install'].each { |task| Rake::Task[task].invoke }
end

task :default => :install
