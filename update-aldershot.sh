#!/bin/sh -x

sudo make install && sudo cp templates/* /usr/local/odd-saturdays/templates/ && sudo service httpd reload
