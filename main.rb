require 'tmpdir'
require 'fileutils'

# Define work
case ENV['WORK']
when "ruby"
  def do_work(log_file)
    FileUtils.touch(log_file)
  end
when "shell"
  def do_work(log_file)
   `touch #{log_file}`
  end
else
  raise "No such work #{ENV['WORK']}, must be 'WORK=ruby' or 'WORK=shell'"
end

COUNT = 1000 # Amount of work to be done
RACTORS = []
POISON = "\0\0\0poison\0\0\0".freeze

ractor_queue = Ractor.new do
  loop do
    Ractor.yield Ractor.recv
  end
end

# Make workers
10.times do
  RACTORS << Ractor.new(ractor_queue, POISON) do |ractor_queue, poison|
    while log_file = ractor_queue.take
      break if log_file == poison
      do_work(log_file)
    end

    Ractor.yield "done"
  end
end

Dir.mktmpdir do |dir|
  # Enqueue the work
  COUNT.times.each do |i|
    ractor_queue << "#{dir}/#{i}.log"
  end

  # Stop the workers
  RACTORS.each do
    ractor_queue << POISON
  end

  # Block until workers are stopped
  out = RACTORS.map(&:take)
  puts out if ENV["PUTS_RACTORS"]

  # Check work was done correctly
  log_file_count = Dir.entries(dir).length - 2 # Take out ".." and "."
  if COUNT == log_file_count
    puts "Expected #{COUNT} files, and got #{log_file_count}"
  else
    raise "Expected #{COUNT} files, but only #{log_file_count}"
  end
end
