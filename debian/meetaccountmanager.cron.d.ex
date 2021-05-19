#
# Regular cron jobs for the meetaccountmanager package
#
0 4	* * *	root	[ -x /usr/bin/meetaccountmanager_maintenance ] && /usr/bin/meetaccountmanager_maintenance
