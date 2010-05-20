What is it?
===========

A script to manage a MySQL lagslave by monitoring the age
of a heartbeat created using mk-heartbeat from Maatkit rather
than just the output from SHOW SLAVE STATUS.

The slave status doesn't really reflect actual age of the data
more the age of how long the master took to do the transactions
so if you have a very fast master and a slow slave things get 
very skewed.

Relying on a timestamp generated rather than slave lag metrics 
mean you're controlling the age of data and not the slave status
which in some cases are better.

Most people would probably rather use mk-slave-delay, you should
look at that first.

Setup:
------
Setting up of MySQL slaves isn't going to be covered here. So you should
get your slaves setup first.

Once you have that going you should set up mk-heartbeat on your master.
Download and install Maatkit and make it write into your database regularly:

<pre>
*/5 * * * * mk-heartbeat --create-table --database my_monitor --user=maatkit --update --run-time 1
</pre>

Now on your slave install the lagslave manager:

<pre>
-rwxr-xr-x 1 root root 1051 May 20 08:25 /etc/init.d/lagslaved
-rw-r--r-- 1 root root 169 May 20 08:22 /etc/sysconfig/lagslaved
-rwxr-xr-x 1 root root 4418 May 20 16:34 /usr/sbin/lagslaved
</pre>

The bulk of the config will be in the /etc/sysconfig/lagslaved file:

<pre>
LAGSLAVED_OPTIONS="--lag 43200 --user nagios --database my_monitor --host localhost --logfile /var/log/lagslaved.log --daemonize -i 1 --pid /var/run/lagslaved.pid"
</pre>

The above setup will keep the db behind roughly 12 hours.  How accurate it is depends
on your writes, if you have few writes the master will catch up real quick and you'll see
it fluctuate by a hour or so.

You need to give the daemon some grants into your DB:

<pre>
GRANT REPLICATION CLIENT, SUPER ON *.* TO 'nagios'@'localhost';
GRANT SELECT ON `my_monitor`.`heartbeat` TO 'nagios'@'localhost';
</pre>

We've included a simple nagios check script:

<pre>
$ /usr/local/bin/check_lagslave.rb --user nagios -d my_monitor -r 39600:46800
OK: 42825 seconds behind master|lag=42825
</pre>

Here we're checking that the DB is behind between 39600 seconds and 46800, the script
provides performance data so you can easily graph your slave state

Contact:
--------
You can contact me on rip@devco.net or follow my blog at http://www.devco.net I am also on twitter as ripienaar
