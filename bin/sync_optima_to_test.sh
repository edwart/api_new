#!/bin/sh
# sync database Optima to Optima_test

#mysqlhotcopy --dryrun Optima Optima_test --user=root --password=gemini2 --addtodest

# skip document and accesslog tables as they are huge and not needed
# cands has a couple of fixture records not to overwrite
#mysqlhotcopy --dryrun 'Optima./~(document|accesslog).*/' Optima_test --user=root --password=gemini2 --addtodest
mysqlhotcopy 'Optima./~(document|accesslog|cands).*/' Optima_test --user=beacon --password=saturn5 --addtodest --keepold

[ ! -h /var/lib/mysql/Optima_test ] && ln -s /usr2/mysqldata/Optima_test /var/lib/mysql/Optima_test

