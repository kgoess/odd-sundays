#!/bin/sh -x

sudo make install && sudo cp templates/* /usr/local/odd-sundays/templates/ && sudo service httpd reload
