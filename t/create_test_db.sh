#!/bin/sh -v
sqlite3 test.db < test.sql 

# to create schema model classes
# $ dbicdump -o dump_directory=./1 TalApi::V1::Model::Test::Schema dbi:SQLite:./test.db
