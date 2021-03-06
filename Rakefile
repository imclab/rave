require 'rubygems'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'spec/rake/spectask'
require 'rake/clean'
require 'yaml'
require 'fileutils'
include FileUtils

# Non-user config.
DEPS = YAML.load_file(File.join('lib', 'gems.yaml'))

SPEC = Gem::Specification.new do |s|
  s.platform = (RUBY_PLATFORM == 'java') ? 'java' : 'ruby'
  s.required_ruby_version = '>= 1.8.6'
  s.name = "rave"
  s.rubyforge_project = 'rave'
  s.version = "0.2.0"
  s.authors = ["Jason Rush", "Jay Donnell"]
  s.email = 'diminish7@gmail.com'
  s.homepage = 'http://github.com/diminish7/rave'
  s.summary = "A Google Wave robot client API for Ruby"
  s.description = "A toolkit for building Google Wave robots in Ruby"
  s.files = FileList['lib/**/*', 'bin/*']
  s.bindir = 'bin'
  s.executables = []
  s.require_path = "lib"
  s.has_rdoc = true
  DEPS['all'].each { | name, version | s.add_runtime_dependency( name, version ) }
  DEPS['jruby'].each { | name, version | s.add_runtime_dependency( name, version ) if s.platform.to_s == 'java' }
  DEPS['mri'].each { | name, version | s.add_runtime_dependency( name, version ) if s.platform.to_s == 'ruby' }
  s.executables = 'rave'
end

NAME = "#{SPEC.name}-#{SPEC.version}"

PACKAGE_DIR = './pkg'
SPEC_FILE = "#{PACKAGE_DIR}/#{SPEC.name}.gemspec"
GEM_FILE = "#{PACKAGE_DIR}/#{NAME}.gem"

RDOC_DIR = './doc/rdoc'

RELEASE_DIR = './release'

RELEASE_FILE = "#{RELEASE_DIR}/#{NAME}_source.7z"
RELEASE_TMP_DIR = "#{RELEASE_DIR}/tmp/#{NAME}"

CLOBBER.include FileList[GEM_FILE, RDOC_DIR, RELEASE_FILE]
CLEAN.include FileList[SPEC_FILE, RELEASE_TMP_DIR]

Rake::GemPackageTask.new(SPEC) do |pkg|
end

# File dependencies for the gem.
task :package => FileList[__FILE__, 'lib/**/*', 'bin/*']

# TODO: How do we tell is the package is newer than the gem installed?
file GEM_FILE => :package
desc "Install gem package"
task :install => GEM_FILE do
  cmd = "gem install #{GEM_FILE}"
  cmd = "jruby -S #{cmd}" if RUBY_PLATFORM == 'java'
  system cmd
end

desc "Create .gemspec file (useful for github)"
task :gemspec => SPEC_FILE
file SPEC_FILE => FileList[__FILE__, 'lib/**/*', 'bin/*'] do
  puts "Generating #{SPEC_FILE}"
  File.open(SPEC_FILE, "w") do |f|
    f.puts SPEC.to_ruby
  end
end

desc 'Publish rdoc to RubyForge (only for Diminish7).'
task :publish do
  "scp -r #{RDOC_DIR} diminish7@rubyforge.org:/var/www/gforge-projects/rave/"
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = RDOC_DIR
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.add(%w(*.rdoc lib/exceptions.rb lib/models/*.rb lib/ops/*.rb))
  rdoc.title = 'Rave API'
end

Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
end

# Synonym for backwards compatibility.
task :test => :spec

example_tasks = [
  [:build,   "Build WAR file",      [:install], "rave war"],
  [:deploy,  "Deploy to appengine", [:install], "rave appengine_deploy"],
  [:spec,    "Run specs",           [],         "jruby -S spec spec/**/*_spec.rb"],
  [:clobber, "Clobber files",       [],         "rave cleanup"],
]
examples = []
# Run rake tasks on the example robots individually.
FileList['examples/*'].each do |path|
  example = File.basename(path)
  examples << example

  namespace example do
    example_tasks.each do |t, desc, depends, command|
      desc "#{desc} for #{example} robot"
      task t => depends do
        cd path do
          system command
        end
      end
    end
  end
end

# Perform tasks for all robots at once.
namespace :examples do
  example_tasks.each do |t, desc, depends, command|
    desc "#{desc} for all example robots"
    task t => examples.map {|e| :"#{e}:#{t}" }
  end
end

# Include example robot tasks in our general ones.
[:clobber].each do |t|
  task t => :"examples:#{t}"
end

file RELEASE_FILE => [:package, :gemspec, :rdoc]
desc "Generate #{RELEASE_FILE}"
task :release => RELEASE_FILE do
  mkdir_p RELEASE_DIR
  rm_r RELEASE_TMP_DIR if File.exist?(RELEASE_TMP_DIR)
  mkdir_p RELEASE_TMP_DIR
  FileList[%w(doc lib bin pkg spec examples *.rdoc MIT-LICENSE Rakefile)].each do |dir|
    cp_r dir, RELEASE_TMP_DIR
  end
  rm RELEASE_FILE if File.exist? RELEASE_FILE

  puts "\nPacking file (#{RELEASE_FILE})..."
  %x(7z a #{RELEASE_FILE} #{RELEASE_TMP_DIR})
  puts "Release file (#{RELEASE_FILE}) created (#{File.size(RELEASE_FILE) / 1000000}MB)."
end
