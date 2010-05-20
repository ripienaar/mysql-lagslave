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

Contact:
--------
You can contact me on rip@devco.net or follow my blog at http://www.devco.net I am also on twitter as ripienaar
