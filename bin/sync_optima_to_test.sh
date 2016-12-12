#!/bin/sh
# sync database Optima to Optima_test

#mysqlhotcopy --dryrun Optima Optima_test --user=root --password=gemini2 --addtodest

# skip document and accesslog tables as they are huge and not needed
#mysqlhotcopy --dryrun 'Optima./~(document|accesslog).*/' Optima_test --user=root --password=gemini2 --addtodest
mysqlhotcopy 'Optima./~(document|accesslog).*/' Optima_test --user=beacon --password=saturn5 --addtodest

