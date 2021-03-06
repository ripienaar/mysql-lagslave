#!/usr/bin/ruby

# Simple script to monitor lagslave delays with
# nagios based on the age of a heartbeat time stamp
# and an acceptible range.

require 'rubygems'
require 'mysql'
require 'optparse'

options = {:user => 'nagios',
           :database => 'heartbeat',
           :table => 'heartbeat',
           :host => "localhost",
           :password => "",
           :mode => :nagios,
           :logfile => "/dev/stdout",
           :check_threads => false,
           :range => "39600:46800" }#Plus/minus one hour for a default lag of 12 hours.

parser = OptionParser.new

parser.separator ""
parser.separator "Monitors a lagged MySQL slave."
parser.separator ""

parser.on('-u', '--user USER', 'User to connect as') do |f|
    options[:user] = f
end

parser.on('-t', '--table TABLE', 'Heartbeat table') do |f|
    options[:table] = f
end

parser.on('-d', '--database DATABASE', 'Heartbeat database') do |f|
    options[:database] = f
end

parser.on('-h', '--host HOST', 'Host to connect to') do |f|
    options[:host] = f
end

parser.on('--threads', 'Check the slave threads as well as ranges') do |f|
    options[:check_threads] = true
end

parser.on('-p', '--password PASSWORD', 'Password to use') do |f|
    options[:password] = f
end

parser.on('-r', '--range RANGE', 'Set acceptable delay range') do |f|
    options[:range] = f
end

parser.on('-m', '--mode MODE', 'Sets output mode either cacti or nagios') do |f|
    case f
        when "nagios"
            options[:mode] = :nagios
        when "cacti"
            options[:mode] = :cacti
        else
            puts "Unsupported output mode #{f} should be 'nagios' or 'cacti'"
            exit 3
    end
end

begin
    parser.parse!

    dbh = Mysql.real_connect(options[:host], options[:user], options[:password], options[:database])

    heartbeat = dbh.query("select unix_timestamp(now()) - unix_timestamp(ts) as seconds from #{options[:table]}").fetch_hash
    age = heartbeat["seconds"].to_i

    rng = options[:range].split(':')
    lowend = rng[0].to_i
    highend = rng[1].to_i
    range = Range.new(rng[0].to_i, rng[1].to_i)

    if options[:mode] == :nagios
        # First we check the threads, just exit critical if those are down
        if options[:check_threads]
            replication = dbh.query("show slave status").fetch_hash

            raise "Database does not appear to be configured as a slave" if replication.nil?

            io_thread = replication["Slave_IO_Running"]
            sql_thread = replication["Slave_SQL_Running"]

            unless io_thread == "Yes" && sql_thread == "Yes"
                puts "CRITICAL: IO Thread: #{io_thread} SQL Thread: #{sql_thread}"
                STDOUT.flush
                exit! 2
            end
        end

        # Now check the ages
        if range.include?(age)
            puts "OK: #{age} is between Max:#{rng[1]} and Min:#{rng[0]}|lag=#{age}"
            STDOUT.flush
            exit! 0

        else
            if age < lowend
                puts "CRITICAL: #{lowend - age} seconds faster than allowed #{lowend} seconds|lag=#{age}"
            elsif age > highend
                puts "CRITICAL: #{age - highend} seconds slower than allowed #{highend} seconds|lag=#{age}"
            end
            STDOUT.flush
            exit! 2
        end
    else
        puts "lag:#{age} low:#{lowend} high:#{highend}"
    end
rescue Exception => e
    puts "UNKNOWN: #{e}"
    exit 3
end
