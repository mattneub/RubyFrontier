# stolen from http://stackoverflow.com/questions/5232294/testing-that-a-method-calls-super-in-ruby

require 'stringio'

module RedirectIo
  def setup
    $stderr = @stderr = StringIO.new
    $stdin = @stdin = StringIO.new
    $stdout = @stdout = StringIO.new
    super
  end

  def teardown
    $stderr = STDERR
    $stdin = STDIN
    $stdout = STDOUT
    super
  end
end
