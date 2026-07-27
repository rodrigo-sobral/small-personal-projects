#!/usr/bin/expect

set timeout 20

set cmd [lrange $argv 2 end]
set totp [lrange $argv 1 1]
set password [lindex $argv 0]

set password [exec echo $password | base64 -d]
set totp [exec echo $totp | base64 -d]

eval spawn $cmd
expect "Password:"
send "$password\r"
expect "2nd factor"
send "$totp\r"
interact
