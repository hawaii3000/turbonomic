You can use a cron job to set up the script to run daily at 5 PM. Follow the steps below:

1.Open crontab:

crontab -e

2.Add the following line to schedule the script to run every day at 5 PM:

0 17 * * * /root/turbo-auto-upgrade/upgrade-check.sh

This configuration will run the /root/turbo-auto-upgrade/upgrade-check.sh script every day at 17:00 (5 PM in 24-hour format).

3.Save the changes and confirm that the new job has been added to cron.

Now, the script will be executed daily at 5 PM.
