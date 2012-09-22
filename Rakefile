require 'rake'
require 'rbconfig'

task :test do
  tm = `mdfind "kMDItemCFBundleIdentifier == 'com.macromates.textmate'"`
  tm.chomp!
  tm += "/Contents/SharedSupport/Support"
  ENV['TM_SUPPORT_PATH'] = tm
  tests = nil # make available from block
  Dir.chdir File.dirname(File.expand_path(__FILE__)) do
    tests = Dir.glob 'RubyFrontier.tmbundle/Support/tests/tc_*.rb'
  end
  tests = tests.map { |test| File.expand_path test }
  $stdout.sync
  
  RUBY = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
  puts "\nUsing #{RUBY}\n"
  Dir.chdir "RubyFrontier.tmbundle" do
    tests.each do |test|
      $stdout.write "\n\n=============\n\nrunning test: #{test}\n\n"
      $stdout.write `#{RUBY} "#{test}"`
    end
  end
end


