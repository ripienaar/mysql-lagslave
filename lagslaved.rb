#!/usr/bin/ruby

# Simple script to stop and stop a MySQL slave 
# based on the age of a heartbeat time stamp
# inserted on the master using mk-heartbeat from
# maatkit.
#
# We use this technique rather than mk-slave-delay
# since mk-slave-delay does not work well when replicating
# from a fast host to a slow host and timings are 
# skewed.

require 'rubygems'
require 'mysql'
require 'optparse'
require 'logger'

options = {:lag => 3600,
           :user => 'nagios',
           :database => 'heartbeat',
           :host => "localhost",
           :password => "",
           :daemonize => false,
           :debug => false,
           :interval => 1,
           :logfile => "/dev/stdout",
           :pidfile => "/var/run/lagslaved.pid"}

parser = OptionParser.new

parser.separator ""
parser.separator "Manages a lagged MySQL slave by monitoring mk-heartbeat generated data"
parser.separator ""

parser.on('-l', '--lag LAG', 'Desired delay behind master') do |f|
    options[:lag] = f.to_i
end

parser.on('-i', '--interval INTERVAL', 'Interval between slave status checks') do |f|
    options[:interval] = f.to_i
end

parser.on('-u', '--user USER', 'User to connect as') do |f|
    options[:user] = f
end

parser.on('-d', '--database DATABASE', 'Heartbeat database') do |f|
    options[:database] = f
end

parser.on('-h', '--host HOST', 'Host to connect to') do |f|
    options[:host] = f
end

parser.on('-p', '--password PASSWORD', 'Password to use') do |f|
    options[:password] = f
end

parser.on('--pid PIDFILE', 'Pidfile to write') do |f|
    options[:pidfile] = f
end

parser.on('-d', '--daemonize', 'Run in the backgroun') do |f|
    options[:daemonize] = f
end

parser.on('--logfile LOGFILE', 'Logfile to write') do |f|
    options[:logfile] = f
end

parser.on('-v', '--debug', 'Log at debug level') do |f|
    options[:debug] = f
end

parser.parse!

# Does something as a background daemon
def daemonize
    fork do
        Process.setsid
        exit if fork
        Dir.chdir('/tmp')
        STDIN.reopen('/dev/null')
        STDOUT.reopen('/dev/null', 'a')
        STDERR.reopen('/dev/null', 'a')

        yield
    end
end


# Loops and manages the slave
def manage_slave(options)
    dbh = Mysql.real_connect(options[:host], options[:user], options[:password], options[:database])

    itr = 0

    loop do
        heartbeat = dbh.query("select now() - ts as seconds from heartbeat").fetch_hash
        slave = dbh.query("show slave status").fetch_hash
        age = heartbeat["seconds"].to_i
    
        @log.info("Slave currently #{age} seconds behind master") if itr == 0

        if slave["Slave_SQL_Running"] == "Yes"
            if age < options[:lag] 
                @log.info "Slave running #{age} behind: needs to stop"
                dbh.query("stop slave SQL_THREAD")
            else
                @log.debug "Slave running #{age} behind: keeping it running"
            end
        else
            # if it's lag + 90 seconds behind start it
            if age > options[:lag] + 90
                @log.info "Slave stopped #{age} behind: needs to start"
                dbh.query("start slave")
            else
                @log.debug "Slave stopped #{age} behind: keeping it stopped"
            end
        end
    
        itr += 1
        sleep options[:interval]
    end
end

# start a slave slave manager, any exception except
# interrupt will just result in a 5 second sleep and
# a retry
def run(options)
    begin
        manage_slave(options)
    rescue Interrupt
        exit!
    rescue Exception => e
        @log.error "Failed to manage slave: #{e}"
        sleep 5
        retry
    end
end

@log = Logger.new(options[:logfile], 10, 1024000)
if options[:debug]
    @log.level = Logger::DEBUG
else
    @log.level = Logger::INFO
end

Signal.trap("TERM") do
    @log.info("Received TERM signal, terminating")
    exit!
end

options.each_pair {|k,v| @log.debug("#{k} => #{v}")}

if options[:daemonize]
    daemonize do
        if options[:pidfile]
            begin
                File.open(options[:pidfile], 'w') {|f| f.write(Process.pid) }
            rescue Exception => e
            end
        end

        @log.info("Lagslave starting in the background with #{options[:lag]} lag")
        run(options)
    end
else
    @log.info("Lagslave starting in the foreground with #{options[:lag]} lag")
    run(options)
end
